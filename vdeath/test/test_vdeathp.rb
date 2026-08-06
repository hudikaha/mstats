# coding: utf-8

require 'csv'
require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class VdeathpTest < Minitest::Test
  SCRIPT = File.expand_path('../import/vdeathp.rb', __dir__)
  GAMMA_SCRIPT = File.expand_path('../import/kcor_gamma.rb', __dir__)
  HEADER = 'id,age,sex,death,dose1,pharma1,lot1,dose2,pharma2,lot2,in,out,reason_out,age_death'
  DATA = <<~CSV
    number,age,sex,death,dose1,pharma1,lot1,dose2,pharma2,lot2,in,out,reason,age_at_death
    1,80,male,2023-06-15,2021-06-01,Pfizer,A,2022-01-01,Moderna,B,,,,78
    2,80〜84歳,female,,2021-07-01,Pfizer,C,,,,,,,
    3,79,male,2024-06-30,,,,,,,,,,79
    4,50歳,female,,2023-01-01,Moderna,D,,,,2022-01-01,2024-01-01,転出,
  CSV

  def setup
    @dir = Dir.mktmpdir
    @header = File.join(@dir, 'jp999999_試験市-Test-JP_header.csv')
    @input = File.join(@dir, 'jp999999_試験市-Test-JP_all.csv')
    File.write(@header, HEADER + "\n")
    File.write(@input, DATA)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def run_command(command, *options)
    output = File.join(@dir, "#{command}.csv")
    stdout, stderr, status = Open3.capture3('ruby', SCRIPT, command, '--headers', @header,
                                            '--output', output, *options, @input)
    assert status.success?, "#{stdout}\n#{stderr}"
    [CSV.read(output, headers: true), stderr]
  end

  def test_personyear_uses_age_at_death
    rows, stderr = run_command('personyear', '--start', '2023-01-01', '--until', '2024-07-01',
                               '--steps', 'all', '--ages', '70-79,80-89,80+,all')
    assert_includes stderr, 'age_reference=2024-07-01'
    death = rows.find { |row| row['age'] == '70-79' && row['dose'] == '2' }
    assert_equal '1', death['deaths']
  end

  def test_fast_personyear_matches_legacy_output
    options = %w[--start 2021-02-01 --until 2024-07-01 --steps 1,3,6,all --ages 00-09,50-59,70-79,80-89,80+,all]
    fast, = run_command('personyear', *options)
    legacy, = run_command('personyear', '--legacy-personyear', *options)
    assert_equal legacy.map(&:to_h), fast.map(&:to_h)
  end

  def test_spread_weekly_dates_is_deterministic_and_rejects_two_doses_in_one_week
    input = File.join(@dir, 'weekly.csv')
    output = File.join(@dir, 'weekly-py.csv')
    report = File.join(@dir, 'weekly-report.json')
    CSV.open(input, 'w') do |csv|
      csv << %w[id age vbirthday date_death date_in date_out date_dose1 date_dose2]
      csv << %w[10 80 1940-01-01 2023-06-18 2021-05-23 _ 2023-06-18 _]
      csv << %w[11 80 1940-01-01 _ 2021-05-23 2024-01-07 2022-01-02 2022-01-02]
    end
    stdout, stderr, status = Open3.capture3(
      'ruby', SCRIPT, 'personyear', '--output', output, '--report', report,
      '--spread-weekly-dates', 'v1', '--start', '2023-01-01', '--until', '2024-02-01',
      '--steps', 'all', '--ages', 'all', '--areacode', 'test', '--area', 'Test', '--areaj', '試験', input
    )
    assert status.success?, "#{stdout}\n#{stderr}"
    rows = CSV.read(output, headers: true)
    assert_equal '1', rows.find { |row| row['dose'] == '1' }['deaths']
    assert_equal 1, JSON.parse(File.read(report)).dig('stats', 'same_week_doses')

    second = File.join(@dir, 'weekly-py-second.csv')
    _stdout, stderr, status = Open3.capture3(
      'ruby', SCRIPT, 'personyear', '--output', second, '--spread-weekly-dates', 'v1',
      '--start', '2023-01-01', '--until', '2024-02-01', '--steps', 'all', '--ages', 'all',
      '--areacode', 'test', '--area', 'Test', '--areaj', '試験', input
    )
    assert status.success?, stderr
    assert_equal File.read(output), File.read(second)
  end

  def test_february_29_birthday_changes_age_on_march_1_in_non_leap_year
    input = File.join(@dir, 'leap-birthday.csv')
    CSV.open(input, 'w') do |csv|
      csv << %w[id age vbirthday]
      csv << %w[10 82 1940-02-29]
    end
    output = File.join(@dir, 'leap-py.csv')
    stdout, stderr, status = Open3.capture3(
      'ruby', SCRIPT, 'personyear', '--output', output, '--start', '2023-02-28', '--until', '2023-03-02',
      '--age-reference', '2023-03-02',
      '--steps', 'all', '--ages', '82-82,83-83,all', '--areacode', 'test', '--area', 'Test', '--areaj', '試験', input
    )
    assert status.success?, "#{stdout}\n#{stderr}"
    all = CSV.read(output, headers: true).find { |row| row['age'] == 'all' && row['dose'] == '0' }
    assert_equal '2', all['persondays']
    assert_equal '1', CSV.read(output, headers: true).find { |row| row['age'] == '82-82' && row['dose'] == '0' }['persondays']
    assert_equal '1', CSV.read(output, headers: true).find { |row| row['age'] == '83-83' && row['dose'] == '0' }['persondays']
  end

  def test_future_virtual_birthday_is_read_and_observation_starts_at_birth
    input = File.join(@dir, 'future-birthday.csv')
    CSV.open(input, 'w') do |csv|
      csv << %w[id age vbirthday]
      csv << %w[10 -10--1 2024-01-15]
    end
    output = File.join(@dir, 'future-py.csv')
    stdout, stderr, status = Open3.capture3(
      'ruby', SCRIPT, 'personyear', '--output', output, '--start', '2024-01-01', '--until', '2024-02-01',
      '--age-reference', '2024-02-01', '--steps', 'all', '--ages', '00-09,all',
      '--areacode', 'test', '--area', 'Test', '--areaj', '試験', input
    )
    assert status.success?, "#{stdout}\n#{stderr}"
    all = CSV.read(output, headers: true).find { |row| row['age'] == 'all' && row['dose'] == '0' }
    assert_equal '17', all['persondays']
    assert_equal '1', all['lives']
  end

  def test_grouped_age_imputation_is_deterministic
    first, = run_command('anonymize')
    second, = run_command('anonymize')
    assert_equal first.map(&:to_h), second.map(&:to_h)
    assert_equal '80-89', first[1]['age']
    refute_nil first[1]['vbirthday']
  end

  def test_anonymized_output_can_be_read_again
    original, = run_command('personyear', '--start', '2023-01-01', '--until', '2024-07-01',
                            '--steps', 'all', '--ages', 'all')
    anonymized, = run_command('anonymize')
    refute_empty anonymized.map { |row| row['date_out'] }.compact
    anonymous_file = File.join(@dir, 'anonymize.csv')
    roundtrip_file = File.join(@dir, 'roundtrip.csv')
    stdout, stderr, status = Open3.capture3('ruby', SCRIPT, 'personyear', '--output', roundtrip_file,
                                            '--start', '2023-01-01', '--until', '2024-07-01',
                                            '--steps', 'all', '--ages', 'all', anonymous_file)
    assert status.success?, "#{stdout}\n#{stderr}"
    roundtrip = CSV.read(roundtrip_file, headers: true)
    before = original.find { |row| row['age'] == 'all' && row['dose'] == 'all' }
    after = roundtrip.find { |row| row['age'] == 'all' && row['dose'] == 'all' }
    assert_equal before['deaths'], after['deaths']
    difference = (before['persondays'].to_i - after['persondays'].to_i).abs
    fields = %w[id date_in date_out date_death]
    detail = anonymized.map { |row| fields.to_h { |field| [field, row[field]] } }
    assert_operator difference, :<=, 18, "#{before['persondays']} -> #{after['persondays']} #{detail}"

    reanonymized_file = File.join(@dir, 'reanonymized.csv')
    _stdout, stderr, status = Open3.capture3('ruby', SCRIPT, 'anonymize', '--output', reanonymized_file,
                                             anonymous_file)
    assert status.success?, stderr
    reanonymized = CSV.read(reanonymized_file, headers: true)
    assert_equal anonymized.map { |row| row['vbirthday'] }, reanonymized.map { |row| row['vbirthday'] }
  end

  def test_all_commands_generate_rows
    commands = {
      'afterdose' => %w[--weeks 1-2 --ages 70-79,80-89,80+,all],
      'kcor' => %w[--cutoff-start 2023-01-01 --cutoff-until 2023-02-01 --ages 70-79,80-89,all],
      'excess' => %w[--start-year 2023 --until-year 2024 --standard-year 2024]
    }
    commands.each do |command, options|
      rows, = run_command(command, *options)
      refute_empty rows, command
    end
  end

  def test_step_prefix_distinguishes_source_date_results
    personyear, = run_command('personyear', '--steps', '1,all', '--step-prefix', 'org', '--ages', 'all')
    assert_equal %w[org1 orgall], personyear.map { |row| row['step'] }.uniq

    afterdose, = run_command('afterdose', '--weeks', '1-2', '--step-prefix', 'org', '--ages', 'all')
    assert_equal ['orgweek'], afterdose.map { |row| row['step'] }.uniq
  end

  def test_birth_year_band_iso_weeks_and_first_infection_filter
    input = File.join(@dir, 'czech.csv')
    output = File.join(@dir, 'czech-anonymized.csv')
    CSV.open(input, 'w') do |csv|
      csv << %w[id infection birth_year sex death dose1 pharma1 dose2]
      csv << %w[10 0 1940-1944 female 2024-20 2021-19 CO01 2021-25]
      csv << %w[11 1 1970-1974 male _ 2024-30 CO24]
      csv << %w[12 2 1970-1974 male 2023-10]
      csv << %w[13 0 2022-2024 female]
    end
    stdout, stderr, status = Open3.capture3(
      'ruby', SCRIPT, 'anonymize', '--output', output,
      '--first-infection-only', '--iso-week-dates',
      '--areacode', 'cze', '--area', 'Czech Republic', '--areaj', 'チェコ',
      '--age-reference', '2024-09-02', input
    )
    assert status.success?, "#{stdout}\n#{stderr}"
    rows = CSV.read(output, headers: true)
    assert_equal 3, rows.length
    birthday = Date.parse(rows[0]['vbirthday'])
    assert_operator birthday, :>=, Date.new(1940, 1, 1)
    assert_operator birthday, :<=, Date.new(1944, 12, 31)
    assert_equal '2021-W19', rows[0]['cweek_dose1']
    assert_equal Date.commercial(2021, 19, 7).to_s, rows[0]['date_dose1']
    assert_equal 'pfizer', rows[0]['pharma_dose1']
    assert_equal 'pfizer', rows[1]['pharma_dose1']
    assert_equal '2024-W20', rows[0]['cweek_death']
    assert_includes stderr, 'rows=3'

    cumulative = File.join(@dir, 'czech-kcor.csv')
    risk = File.join(@dir, 'czech-kcor-risk.csv')
    stdout, stderr, status = Open3.capture3(
      'ruby', SCRIPT, 'kcor', '--output', cumulative, '--risk-output', risk,
      '--cutoff-start', '2021-06-01', '--cutoff-until', '2021-06-01', '--ages', 'all', output
    )
    assert status.success?, "#{stdout}\n#{stderr}"
    risk_rows = CSV.read(risk, headers: true)
    first_risk = risk_rows.find { |row| row['dose'] == '1' }
    assert_equal '1', first_risk['cohort_size']
    assert_equal '1', first_risk['at_risk']
    death_risk = risk_rows.find { |row| row['dose'] == '1' && row['deaths_week'] == '1' }
    refute_nil death_risk
    assert_equal '1', death_risk['deaths']
    cumulative_rows = CSV.read(cumulative, headers: true)
    matching = cumulative_rows.find { |row| row['id'] == death_risk['id'] }
    assert_equal death_risk['deaths'], matching['deaths']
    assert_equal 2, risk_rows.select { |row| row['cweek'] == risk_rows.first['cweek'] }.sum { |row| row['cohort_size'].to_i }

    risk_only = File.join(@dir, 'czech-risk-only.csv')
    stdout, stderr, status = Open3.capture3(
      'ruby', SCRIPT, 'kcor', '--risk-output', risk_only,
      '--cutoff-start', '2021-06-01', '--cutoff-until', '2021-06-01', '--ages', 'all', output
    )
    assert status.success?, "#{stdout}\n#{stderr}"
    assert_equal risk_rows.map(&:to_h), CSV.read(risk_only, headers: true).map(&:to_h)
  end

  def test_gamma_fit_recovers_synthetic_frailty
    input = File.join(@dir, 'gamma-risk.csv')
    params = File.join(@dir, 'gamma-params.csv')
    series = File.join(@dir, 'gamma-series.csv')
    theta = 2.0
    k = 0.001
    alive = 100_000_000
    cumulative_deaths = 0
    previous_hazard = 0.0
    start = Date.new(2021, 1, 3)
    CSV.open(input, 'w') do |csv|
      csv << %w[id areacode area areaj cutoff cweek date age dose cohort_size at_risk deaths_week deaths censored_week]
      80.times do |index|
        date = start + 7 * (index + 1)
        cumulative_hazard = Math.log(1.0 + theta * k * (index + 1)) / theta
        weekly_hazard = cumulative_hazard - previous_hazard
        deaths = (alive * (1.0 - Math.exp(-weekly_hazard))).round
        cumulative_deaths += deaths
        csv << ["test_#{index}", 'test', 'Test', '試験', start, format('%04d-W%02d', date.cwyear, date.cweek),
                date, 'all', 0, 100_000_000, alive, deaths, cumulative_deaths, 0]
        alive -= deaths
        previous_hazard = cumulative_hazard
      end
    end
    stdout, stderr, status = Open3.capture3(
      'ruby', GAMMA_SCRIPT, '--quiet-start', (start + 7).to_s, '--quiet-end', (start + 7 * 80).to_s,
      '--output', params, '--series-output', series, input
    )
    assert status.success?, "#{stdout}\n#{stderr}"
    fit = CSV.read(params, headers: true).first
    assert_in_delta theta, fit['theta'].to_f, 0.01
    assert_in_delta k, fit['k'].to_f, 0.00001
    assert_equal 80, CSV.read(series, headers: true).length
  end
end
