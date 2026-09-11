# coding: utf-8
require 'minitest/autorun'
require 'json'
require 'open3'
require 'tmpdir'
require 'rbconfig'

# 合成recordをElasticsearchの検索条件で絞り、CGIの最終系列を検査する。
# Filter synthetic records with the Elasticsearch query and inspect final CGI series.
class Vdeath2Test < Minitest::Test
  PAGE = File.expand_path('../web/vdeath2.rb', __dir__)
  def setup
    @tmp = Dir.mktmpdir('vdeath2-test-')
    @rows = []
    { 'cze' => { '1' => [[40, 40_000], [10, 20_000]], 'org1' => [[999, 1000], [999, 1000]] },
      'jp13210' => { 'org1' => [[20, 20_000], [8, 16_000]], '1' => [[30, 30_000], [9, 12_000]] },
      'jp22130' => { 'org1' => [[500, 1000], [500, 1000]], '1' => [[500, 1000], [500, 1000]] }
    }.each do |loc, steps|
      steps.each do |step, doses|
        doses.each_with_index { |(deaths, days), dose| add(loc, step, '2021m02', dose, deaths, days) }
      end
    end
    add('cze', '1', '2021m03', 1, 3, 3000)
    @fixture = File.join(@tmp, 'rows.json')
    File.write(@fixture, JSON.generate(@rows))
    @stub = File.join(@tmp, 'search.rb')
    File.write(@stub, <<~CODE)
      require #{File.expand_path('../../lib/mfacts.rb', __dir__).inspect}
      def matches?(row, clause)
        if clause[:term] || clause[:terms]
          key, values = (clause[:term] || clause[:terms]).first
          Array(values).map(&:to_s).include?(row[key.to_s.sub(/\\.keyword$/, '').to_sym].to_s)
        elsif clause[:bool]
          b = clause[:bool]
          Array(b[:filter]).all? { |c| matches?(row, c) } &&
            Array(b[:must_not]).none? { |c| matches?(row, c) } &&
            Array(b[:should]).count { |c| matches?(row, c) } >= b.fetch(:minimum_should_match, 0)
        else
          raise "Unsupported test query: \#{clause}"
        end
      end
      def elastic_search(**opts)
        raise 'Wrong index' unless opts[:index] == 'vdeath'
        rows = JSON.parse(File.read(ENV.fetch('VDEATH_TEST_FIXTURE')), symbolize_names: true)
        rows.select { |row| opts.fetch(:filter).all? { |clause| matches?(row, clause) } }
      end
    CODE
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def add(loc, step, period, dose, deaths, days)
    id = [loc, step, period, 'all', dose].join('_')
    @rows << { _id:id, doc_id:id, loc:loc, area:loc, step:step, period:period,
               age:'all', dose:dose.to_s, deaths:deaths, persondays:days, lives:days / 100,
               mortality:deaths * 36_500_000.0 / days, rr0:1, lb0:0.5, ub0:2 }
  end

  def run_page(src, locations)
    env = { 'REQUEST_METHOD'=>'GET', 'SCRIPT_NAME'=>'vdeath2.rb', 'HTTP_ACCEPT_LANGUAGE'=>'ja',
            'QUERY_STRING'=>"l=ja&c=#{locations}&src=#{src}&ages=all&stacks=deaths&lines=mortality~rr0&bars=mortality&doses=0~1",
            'VDEATH_TEST_FIXTURE'=>@fixture }
    html, err, status = Open3.capture3(env, RbConfig.ruby, '-r', @stub, PAGE)
    assert status.success?, err
    assert html.include?('</html>'), 'Incomplete HTML'
    assert_match(/name="src" value="#{src}" checked/, html)
    refute_includes html, 'selectExclusiveArea'
    data = JSON.parse(html.match(/"values":\s*(\[.*?\])\s*\n\s*}/m)[1])
    [data, html]
  end

  def test_czech_is_identical_for_both_sources_and_not_counted_twice
    org, = run_page('org', 'all~cze')
    anon, = run_page('anon', 'all~cze')
    assert_equal org, anon
    assert_equal 6, org.length
    sum = org.find { |r| r['loc'] == 'all' && r['period'] == '2021-02' && r['dose'] == '0' }
    assert_equal 40, sum['deaths']
    assert_equal 40_000, sum['persondays']
  end

  def test_mixed_areas_use_the_selected_japanese_source
    %w[org anon].each do |src|
      data, html = run_page(src, 'all~cze~jp13210')
      %w[all cze jp13210].each { |loc| assert_match(/name="c" value="#{loc}" checked/, html) }
      refute data.any? { |r| r['loc'] == 'jp22130' }
      totals = data.select { |r| r['loc'] == 'all' && r['period'] == '2021-02' }.to_h { |r| [r['dose'], r] }
      assert_equal(src == 'org' ? 60 : 70, totals['0']['deaths'])
      assert_equal(src == 'org' ? 18 : 19, totals['1']['deaths'])
      days = src == 'org' ? 36_000 : 32_000
      assert_equal days, totals['1']['persondays']
      assert_equal days / 100, totals['1']['lives']
      expected_rr = ((totals['1']['deaths'].to_f / days) / 0.001).round(4)
      assert_equal expected_rr, totals['1']['rr0']
      assert_in_delta totals['1']['deaths'] * 36_500_000.0 / days, totals['1']['mortality'], 1
      extra = data.find { |r| r['loc'] == 'all' && r['period'] == '2021-03' }
      assert_equal 3, extra['deaths']
      assert_equal '-', extra['rr0']
    end
  end

  def test_japan_only_does_not_include_czech_data
    data, = run_page('org', 'all~jp13210')
    assert_equal %w[all jp13210], data.map { |r| r['loc'] }.uniq.sort
    assert_equal 28, data.select { |r| r['loc'] == 'all' }.sum { |r| r['deaths'] }
  end
end
