# coding: utf-8
# frozen_string_literal: true

require 'csv'
require 'date'
require 'minitest/autorun'
require_relative '../lib/mstats2'

class Mstats2Test < Minitest::Test
  def test_document_id_has_exactly_eight_components
    record = {
      loc_code: 'JPN', yearweek: '2024w01', category: 'death', rate: '',
      death_code: '00000', algo: 'whostd', type: 'conf', sex: 'both'
    }
    assert_equal 'JPN_2024w01_death__00000_whostd_conf_both', Mstats.document_id(record)
    assert_equal 8, Mstats.document_id(record).split('_', -1).length
  end

  def test_document_id_rejects_underscore_inside_component
    record = {
      loc_code: 'JPN', year: 2024, category: 'death', rate: '', death_code: '00000',
      algo: 'who_standard', type: 'conf', sex: 'both'
    }
    assert_raises(ArgumentError) { Mstats.document_id(record) }
  end

  def test_excess_changes_algo_component_without_changing_type
    rows = Mstats.new
    (2015..2020).each do |year|
      record = {
        loc_code: 'JPN', yearweek: "#{year}w01", category: 'death', rate: '',
        death_code: '00000', algo: '', type: 'conf', sex: 'both', year: year,
        week: 1, age_all: 100 + year - 2015
      }
      id = Mstats.document_id(record)
      record[:doc_id] = id
      rows[id] = record
    end

    result = rows.excess(years: 5, to: 2019, apply: 2020)
    id = 'JPN_2020w01_death__00000_avg5to2019_conf_both'
    assert result.key?(id)
    assert_equal 'conf', result.fetch(id)[:type]
  end
end
