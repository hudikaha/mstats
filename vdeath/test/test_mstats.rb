# coding: utf-8
# frozen_string_literal: true

require 'csv'
require 'date'
require 'minitest/autorun'
require_relative '../lib/mstats'

class MstatsTest < Minitest::Test
  def test_document_id_has_exactly_eight_components
    record = {
      loc_code: 'jpn', yearweek: '2024w01', category: 'death', rate: '',
      death_code: 'allcause', algo: 'whostd', type: 'cfm', sex: 'both'
    }
    assert_equal 'jpn_2024w01_death__allcause_whostd_cfm_both', Mstats.document_id(record)
    assert_equal 8, Mstats.document_id(record).split('_', -1).length
  end

  def test_document_id_rejects_underscore_inside_component
    record = {
      loc_code: 'jpn', year: 2024, category: 'death', rate: '', death_code: 'allcause',
      algo: 'who_std', type: 'cfm', sex: 'both'
    }
    assert_raises(ArgumentError) { Mstats.document_id(record) }
  end

  def test_excess_changes_algo_component_without_changing_type
    rows = Mstats.new
    (2015..2020).each do |year|
      record = {
        loc_code: 'jpn', yearweek: "#{year}w01", category: 'death', rate: '',
        death_code: 'allcause', algo: '', type: 'cfm', sex: 'both', year: year,
        week: 1, age_all: 100 + year - 2015
      }
      id = Mstats.document_id(record)
      record[:doc_id] = id
      rows[id] = record
    end

    result = rows.excess(years: 5, to: 2019, apply: 2020)
    id = 'jpn_2020w01_death__allcause_avg5to2019_cfm_both'
    assert result.key?(id)
    assert_equal 'cfm', result.fetch(id)[:type]
  end
end
