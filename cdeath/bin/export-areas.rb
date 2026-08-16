#!/usr/bin/ruby
# coding: utf-8
# frozen_string_literal: true

require 'json'

abort 'Usage: export-areas.rb OUTPUT.json' unless ARGV.length == 1
load File.expand_path('../../vdeath/lib/mstats.rb', __dir__)

overrides = {
  'XKX' => { en: 'Kosovo', ja: 'コソボ' },
  'PRK' => { en: 'North Korea', ja: '北朝鮮' },
  'MYT' => { en: 'Mayotte', ja: 'マヨット' },
  'REU' => { en: 'Réunion', ja: 'レユニオン' },
  'ESH' => { en: 'Western Sahara', ja: '西サハラ' },
  'GUF' => { en: 'French Guiana', ja: 'フランス領ギアナ' },
  'GLP' => { en: 'Guadeloupe', ja: 'グアドループ' },
  'MTQ' => { en: 'Martinique', ja: 'マルティニーク' },
  'PRI' => { en: 'Puerto Rico', ja: 'プエルトリコ' },
  'BLM' => { en: 'Saint Barthélemy', ja: 'サン・バルテルミー' },
  'MAF' => { en: 'Saint Martin (French part)', ja: 'サン・マルタン（フランス領）' },
  'VIR' => { en: 'United States Virgin Islands', ja: 'アメリカ領ヴァージン諸島' },
  'ASM' => { en: 'American Samoa', ja: 'アメリカ領サモア' },
  'GUM' => { en: 'Guam', ja: 'グアム' },
  'MNP' => { en: 'Northern Mariana Islands', ja: '北マリアナ諸島' },
  'ALA' => { en: 'Åland Islands', ja: 'オーランド諸島' },
  'NFK' => { en: 'Norfolk Island', ja: 'ノーフォーク島' },
  'ENG' => { en: 'England and Wales', ja: 'イングランド・ウェールズ（英国）' },
  'SCO' => { en: 'Scotland', ja: 'スコットランド（英国）' },
  'NIR' => { en: 'Northern Ireland', ja: '北アイルランド（英国）' }
}
areas = Locs.merge(overrides).select do |code, _names|
  code.match?(/\A[A-Z]{3}\z/) || code.match?(/\AJP\d{2}\z/)
end.map do |code, names|
  [code.downcase, { area: names.fetch(:en), areaj: names.fetch(:ja) }]
end.to_h

File.write(ARGV.fetch(0), JSON.pretty_generate(areas.sort.to_h) + "\n")
