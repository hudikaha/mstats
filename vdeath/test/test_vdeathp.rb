# coding: utf-8

require 'csv'
require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class VdeathpTest < Minitest::Test
  SCRIPT = File.expand_path('../import/vdeathp.rb', __dir__)
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
end
