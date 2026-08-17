# coding: utf-8

require 'minitest/autorun'
require_relative '../lib/missing_history'

class MissingHistoryTest < Minitest::Test
  def setup
    @observed = {
      'area_1_2022m01_80+_0' => row('0', 20, 1_000),
      'area_1_2022m01_80+_1' => row('1', 3, 2_000),
      'area_1_2022m01_80+_2' => row('2', 7, 6_000),
      'area_1_2022m01_80+_vaxx' => row('vaxx', 10, 8_000),
      'area_1_2022m01_80+_all' => row('all', 30, 9_000)
    }
  end

  def test_builds_all_five_scenarios_without_changing_observations
    scenarios = MissingHistory.build_missing_history_scenarios(@observed)
    assert_equal @observed.length * MissingHistory::RATES.length, scenarios.length
    @observed.each do |id, original|
      actual = scenarios.fetch("#{id}__miss0")
      original.each { |field, value| assert_equal value, actual[field], field }
      assert_equal 0, actual[:miss]
    end
  end

  def test_redistributes_unvaccinated_deaths_by_person_days
    scenarios = MissingHistory.build_missing_history_scenarios(@observed)
    dose0 = scenarios.fetch('area_1_2022m01_80+_0__miss20')
    dose1 = scenarios.fetch('area_1_2022m01_80+_1__miss20')
    dose2 = scenarios.fetch('area_1_2022m01_80+_2__miss20')
    vaxx = scenarios.fetch('area_1_2022m01_80+_vaxx__miss20')
    all = scenarios.fetch('area_1_2022m01_80+_all__miss20')

    assert_in_delta 16, dose0[:deaths], 1e-10
    assert_in_delta 4, dose1[:deaths], 1e-10
    assert_in_delta 10, dose2[:deaths], 1e-10
    assert_in_delta 14, vaxx[:deaths], 1e-10
    assert_in_delta 30, all[:deaths], 1e-10
    assert_equal [1_000, 2_000, 6_000], [dose0, dose1, dose2].map { |row| row[:persondays] }
  end

  def test_each_rate_starts_from_the_same_observed_data
    scenarios = MissingHistory.build_missing_history_scenarios(@observed)
    expected = {0 => 20, 1 => 19.8, 5 => 19, 10 => 18, 20 => 16}
    expected.each do |rate, deaths|
      row = scenarios.fetch("area_1_2022m01_80+_0__miss#{rate}")
      assert_in_delta deaths, row[:deaths], 1e-10
    end
  end

  private

  def row(dose, deaths, persondays)
    {
      loc: 'area', step: '1', period: '2022-01', age: '80+', dose: dose,
      deaths: deaths, persondays: persondays, lives: 100, mortality: 0,
      rr0: '-', lb0: '-', ub0: '-'
    }
  end
end
