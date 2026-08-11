#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'csv'
require_relative 'mstats2026'

abort 'Usage: us-infant-yearly.rb BIRTHS_AND_INFANT_DEATHS.csv > YEARLY.csv' unless ARGV.length == 1

rows = {}
CSV.foreach(ARGV[0], headers: true) do |input|
  year = Integer(input.fetch('year'))
  births = Integer(input.fetch('births'))
  deaths = Integer(input.fetch('infant_deaths'))
  common = { loc_code: 'usa', location: 'United States', src_url: [Mstats2026::US_VITAL_STATS_URL],
             date: "#{year}-01-01", year: year, sex: 'both' }

  birth_id = "usa_#{year}_birth__live__both"
  rows[birth_id] = common.merge(id: birth_id, category: 'birth', type: 'live', age_all: births)

  death_id = "usa_#{year}_death__00000__both"
  rows[death_id] = common.merge(id: death_id, category: 'death', death_code: '00000',
                                death_cause: 'All causes (infant deaths)', age_0: deaths)

  rate_id = "usa_#{year}_death_imr_00000__both"
  rows[rate_id] = common.merge(id: rate_id, category: 'death', rate: 'imr', death_code: '00000',
                               death_cause: 'All causes (infant mortality)',
                               age_0: (deaths * 1000.0 / births).round(9))
end

Mstats2026.output_yearly(rows)
