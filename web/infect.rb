#!/usr/bin/ruby
# coding: utf-8
# ruby-indent-level: 4
#

require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require 'date'
require './c19db'
require './cc.rb'

mfacts = [
    File.expand_path('../lib/mfacts.rb', __dir__),
    File.expand_path('lib/mfacts.rb', __dir__)
].find { |path| File.file?(path) }
abort 'lib/mfacts.rb not found' unless mfacts
require mfacts

#
# CGI.new
#
$cgi = CGI.new

#
# Language
#
lang = $cgi['l']
$echeck = ''
$jcheck = ''
$init_locs = ''
if (lang != '' && /^#{lang}/ =~ 'english') ||
   (lang == '' && ENV['HTTP_ACCEPT_LANGUAGE'] !~ /^ja/)
    $l    = :en
    $echeck = 'checked'
    $init_locs = 'ex) ISR,Republic of Korea,Japan,Tokyo'
    $pholder = "Input country/state names and/or ISO-3-letter codes with ','"
else
    $l    = :ja
    $jcheck = 'checked'
    $init_locs = '例) ISR,Republic of Korea,日本,東京都'
    $pholder = "国名(ISO 3文字可)や県名を「,」で区切って入力。「全都道府県」という文字列の可"
end

#
# Locations
#
locs0 = $cgi['c'].gsub(/[、，]/,',')

if ! locs0 || locs0 == ''
    locs = $init_locs.gsub(/^例\) /, '').gsub(/^ex\) /,'').split(/[\~,\,:]/)
else
    locs = locs0.gsub(/^例\) /, '').gsub(/^ex\) /,'').split(/[\~,\,:]/)
end

$start_year = 2020

$max_codes = 50
$codes = []
locs.each do |loc|
    loc2year = loc.to_i
    if $locs[loc] && ! $codes.find{|code| code == loc}
        $codes.push(loc)
        next
    elsif 2020 <= loc2year && loc2year <= 2023
        $start_year = loc2year
    elsif loc == '全都道府県'
        (1..47).each do |i|
            $codes.push(sprintf('jp-%02d', i))
        end
    end
    [:en, :ja].each do |i|
        loc2 = $locs.find { |k,v| v[i]==loc || (v[i].is_a?(String)&&v[i].chop==loc) }
        if ! loc2
            locs2 = $locs.find_all {|k,v| /^#{v[:en]}/ =~ loc || v[:en] =~ /^#{loc}/}
            if locs2.count == 1
                loc2 = locs2[0]
            end
        end
        if ! loc2
            next
        end
        if ! $codes.find { |i| i == loc2[0] }
            $codes.push(loc2[0])
        end
    end
    if $codes.count >= 10
        break
    end
end

init_locs0 = []
$codes.each do |code|
    init_locs0.push($locs[code][:en])
end

if $codes == []
    $codes = ['ISR','JPN','KOR','jp-13']
else
    if locs0 && locs0 != ''
        $init_locs = init_locs0.join(',')
        if $start_year != 2020
            $init_locs += ",#{$start_year}"
        end
    end
end

#
# Height
#
$height = ($cgi['height'] != '' && $cgi['height'].to_i >= 50) ? $cgi['height'].to_i : 200

#
# Width
#
$width = ($cgi['width'] != '') ? $cgi['width'] : '80%'

#
# items and y1axis
#
$y0s = Hash.new
$keys = ['total_cases', 'new_cases', 'new_cases_smoothed', 'total_deaths', 'new_deaths', 'new_deaths_smoothed', 'total_cases_per_million', 'new_cases_per_million', 'new_cases_smoothed_per_million', 'total_deaths_per_million', 'new_deaths_per_million', 'new_deaths_smoothed_per_million', 'reproduction_rate', 'icu_patients', 'icu_patients_per_million', 'hosp_patients', 'hosp_patients_per_million', 'weekly_icu_admissions', 'weekly_icu_admissions_per_million', 'weekly_hosp_admissions', 'weekly_hosp_admissions_per_million', 'total_tests', 'new_tests', 'total_tests_per_thousand', 'new_tests_per_thousand', 'new_tests_smoothed', 'new_tests_smoothed_per_thousand', 'positive_rate', 'total_positive_rate', 'tests_per_case', 'total_tests_per_case', 'tests_units', 'total_vaccinations', 'people_vaccinated', 'people_fully_vaccinated', 'total_boosters', 'new_vaccinations', 'new_vaccinations_smoothed', 'new_vaccinations_per_world', 'new_vaccinations_smoothed_per_world', 'total_vaccinations_per_hundred', 'people_vaccinated_per_hundred', 'people_fully_vaccinated_per_hundred', 'total_boosters_per_hundred', 'new_vaccinations_smoothed_per_million', 'new_people_vaccinated_smoothed', 'new_people_vaccinated_smoothed_per_hundred',
         'new_1doses','new_1doses_smoothed','new_1doses_smoothed_per_million','new_2doses','new_2doses_smoothed','new_2doses_smoothed_per_million','new_3doses','new_3doses_smoothed','new_3doses_smoothed_per_million','total_3doses','total_3doses_per_hundred','new_4doses','new_4doses_smoothed','new_4doses_smoothed_per_million','total_4doses','total_4doses_per_hundred','new_5doses','new_5doses_smoothed','new_5doses_smoothed_per_million','total_5doses','total_5doses_per_hundred','new_6doses','new_6doses_smoothed','new_6doses_smoothed_per_million','total_6doses','total_6doses_per_hundred',
         'new_7doses','new_7doses_smoothed','new_7doses_smoothed_per_million','total_7doses','total_7doses_per_hundred',
         'new_1doses_65over','new_1doses_65over_smoothed','new_1doses_65over_smoothed_per_million','new_2doses_65over','new_2doses_65over_smoothed','new_2doses_65over_smoothed_per_million','new_3doses_65over','new_3doses_65over_smoothed','new_3doses_65over_smoothed_per_million','total_3doses_65over','total_3doses_65over_per_hundred','new_4doses_65over','new_4doses_65over_smoothed','new_4doses_65over_smoothed_per_million','total_4doses_65over','total_4doses_65over_per_hundred','new_5doses_65over','new_5doses_65over_smoothed','new_5doses_65over_smoothed_per_million','total_5doses_65over','total_5doses_65over_per_hundred','new_6doses_65over','new_6doses_65over_smoothed','new_6doses_65over_smoothed_per_million','total_6doses_65over','total_6doses_65over_per_hundred',
         'new_7doses_65over','new_7doses_65over_smoothed','new_7doses_65over_smoothed_per_million','total_7doses_65over','total_7doses_65over_per_hundred',
         'stringency_index', 'population', 'population_density', 'median_age', 'aged_65_older', 'aged_70_older', 'gdp_per_capita', 'extreme_poverty', 'cardiovasc_death_rate', 'diabetes_prevalence', 'female_smokers', 'male_smokers', 'handwashing_facilities', 'hospital_beds_per_thousand', 'life_expectancy', 'human_development_index', 'excess_mortality_cumulative_absolute', 'excess_mortality_cumulative', 'excess_mortality', 'excess_mortality_cumulative_per_million', 'all_cause_deaths_smoothed', 'all_cause_deaths_smoothed_per_million',
         'total_all_cause_deaths_smoothed', 'total_all_cause_deaths_smoothed_per_million',
         'retail_and_recreation_percent_change_from_baseline', 'grocery_and_pharmacy_percent_change_from_baseline', 'parks_percent_change_from_baseline', 'transit_stations_percent_change_from_baseline', 'workplaces_percent_change_from_baseline', 'residential_percent_change_from_baseline',
         'retail_and_recreation_percent_change_from_baseline_smoothed', 'grocery_and_pharmacy_percent_change_from_baseline_smoothed', 'parks_percent_change_from_baseline_smoothed', 'transit_stations_percent_change_from_baseline_smoothed', 'workplaces_percent_change_from_baseline_smoothed', 'residential_percent_change_from_baseline_smoothed',
        ]

$keys.each do |key|
    $y0s[key] = {
        name: key,
        calc: key,
        ja:   '',
        en:   key.gsub('_', ' ').capitalize.
                  gsub(/icu/i , 'ICU').gsub(/gdp/i , 'GDP').
                  gsub(/1d/, '1st d').gsub(/2d/, '2nd d').gsub(/3d/, '3rd d').
                  gsub(/4d/, '4th d').gsub(/5d/, '5th d').gsub(/6d/, '6th d').
                  gsub(/7d/, '7th d'),
        max:  0,
        min:  0,
        sel:  '',
    }
    ['total_all_cause_deaths_smoothed',
     'total_all_cause_deaths_smoothed_per_million'].each do |key2|
        $y0s[key2][:calc] = key2.gsub(/^total_/,'') if key == key2
    end
    jastr = $y0s[key][:en].dup
    if key =~ /new/
        jastr.gsub!(/New/,'')
        jastr = '新規' + jastr
    end
    if key =~ /weekly/
        jastr.gsub!(/Weekly/,'')
        jastr = '週間' + jastr
    end
    if key =~ /_cumulative/
        jastr.gsub!(/ cumulative/,'')
        jastr = '累積' + jastr
    end
    if key =~ /_per_hundred/
        jastr.gsub!(/ per hundred/,'')
        jastr = '100人当りの' + jastr
    elsif key =~ /_per_million/
        jastr.gsub!(/ per million/,'')
        jastr = '100万人当りの' + jastr
    elsif key =~ /_per_thousand/
        jastr.gsub!(/ per thousand/,'')
        jastr = '千人当りの' + jastr
    end
    if key =~ /hospital_beds/
        jastr.gsub!(/Hospital beds/,'')
        jastr += '病床数'
    elsif key =~ /_hosp/
        jastr.gsub!(/ hosp/,'')
        jastr += '入院'
    elsif key =~ /hosp/
        jastr.gsub!(/Hosp/,'')
        jastr += '入院'
    end
    if key =~ /_admissions/
        jastr.gsub!(/ admissions/,'')
        jastr += '受入れ'
    end
    if key =~ /_cases/
        jastr.gsub!(/ cases/,'')
        jastr += '陽性者数'
    elsif key =~ /_all_cause_deaths/
        jastr.gsub!(/ all cause deaths/,'')
        jastr += '全死因死者数'
    elsif key =~ /all_cause_deaths/
        jastr.gsub!(/All cause deaths/,'')
        jastr += '全死因死者数'
    elsif key =~ /_deaths/
        jastr.gsub!(/ deaths/,'')
        jastr += '死者数'
    elsif key =~ /_vaccinations/
        jastr.gsub!(/ vaccinations/,'')
        jastr += '接種数'
    elsif key =~ /_boosters/
        jastr.gsub!(/ boosters/,'')
        jastr += 'ブースター(追加)接種数'
    elsif key =~ /_people_vaccinated/
        jastr.gsub!(/ people vaccinated/,'')
        jastr += '接種者数'
    elsif key =~ /people_vaccinated/
        jastr.gsub!(/People vaccinated/,'')
        jastr += '接種者数'
    elsif key =~ /_people_fully_vaccinated/
        jastr.gsub!(/ people fully vaccinated/,'')
        jastr += '2回接種者数'
    elsif key =~ /people_fully_vaccinated/
        jastr.gsub!(/People fully vaccinated/,'')
        jastr += '2回接種者数'
    elsif key =~ /_1doses_65over/
        jastr.gsub!(/ 1st doses 65over/,'')
        jastr += '1回目接種数(65歳以上)'
    elsif key =~ /_2doses_65over/
        jastr.gsub!(/ 2nd doses 65over/,'')
        jastr += '2回目接種数(65歳以上)'
    elsif key =~ /_3doses_65over/
        jastr.gsub!(/ 3rd doses 65over/,'')
        jastr += '3回目接種数(65歳以上)'
    elsif key =~ /_4doses_65over/
        jastr.gsub!(/ 4th doses 65over/,'')
        jastr += '4回目接種数(65歳以上)'
    elsif key =~ /_5doses_65over/
        jastr.gsub!(/ 5th doses 65over/,'')
        jastr += '5回目接種数(65歳以上)'
    elsif key =~ /_6doses_65over/
        jastr.gsub!(/ 6th doses 65over/,'')
        jastr += '6回目接種数(65歳以上)'
    elsif key =~ /_7doses_65over/
        jastr.gsub!(/ 7th doses 65over/,'')
        jastr += '7回目接種数(65歳以上)'
    elsif key =~ /_1doses/
        jastr.gsub!(/ 1st doses/,'')
        jastr += '1回目接種数'
    elsif key =~ /_2doses/
        jastr.gsub!(/ 2nd doses/,'')
        jastr += '2回目接種数'
    elsif key =~ /_3doses/
        jastr.gsub!(/ 3rd doses/,'')
        jastr += '3回目接種数'
    elsif key =~ /_4doses/
        jastr.gsub!(/ 4th doses/,'')
        jastr += '4回目接種数'
    elsif key =~ /_5doses/
        jastr.gsub!(/ 5th doses/,'')
        jastr += '5回目接種数'
    elsif key =~ /_6doses/
        jastr.gsub!(/ 6th doses/,'')
        jastr += '6回目接種数'
    elsif key =~ /_7doses/
        jastr.gsub!(/ 7th doses/,'')
        jastr += '7回目接種数'
    elsif key =~ /_tests/
        jastr.gsub!(/ tests/,'')
        jastr += '検査数'
    elsif key =~ /_patients/
        jastr.gsub!(/ patients/,'')
        jastr += '患者数'
        jastr += '(重症者数)' if key =~ /ICU/i
    elsif key =~ /excess_mortality/
        jastr.gsub!(/Excess mortality/,'')
        jastr += '超過死亡率'
    end
    if key =~ /total/
        jastr.gsub!(/Total/,'')
        jastr += '累計'
    end
    if key =~ /_absolute/
        jastr.gsub!(/ absolute/,'')
        jastr += '絶対値'
    end
    if key =~ /_per_world/
        jastr.gsub!(/ per world/,'')
        jastr += '世界シェア(%)'
    end
    if key =~ /_smoothed/
        jastr.gsub!(/ smoothed/,'')
        jastr += '(7日平均)' if  key !~ /^total/ && $height >= 200
        key2 = key.gsub('_smoothed','')
        if $y0s[key2]
            $y0s[key2][:calc] = key
        end
    end
    if key =~ /reproduction_rate/
        jastr = '実効再生産数'
    elsif key =~ /total_positive_rate/
        jastr = '陽性率(全期間)'
    elsif key =~ /positive_rate/
        jastr = '陽性率'
    elsif key =~ /total_tests_per_case/
        jastr = '陽性者当りの検査(全期間)'
    elsif key =~ /tests_per_case/
        jastr = '陽性者当りの検査'
    end

    if jastr != ''
        $y0s[key][:ja] = jastr
    end
end

$y0s['retail_and_recreation_percent_change_from_baseline'][:ja] = '小売・娯楽施設の人流(%)'
$y0s['grocery_and_pharmacy_percent_change_from_baseline'][:ja] = '食料品店の人流(%)'
$y0s['parks_percent_change_from_baseline'][:ja] = '公園の人流(%)'
$y0s['transit_stations_percent_change_from_baseline'][:ja] = '駅の人流(%)'
$y0s['workplaces_percent_change_from_baseline'][:ja] = '職場の人流(%)'
$y0s['residential_percent_change_from_baseline'][:ja] = '住宅地の人流(%)'

$y0s['retail_and_recreation_percent_change_from_baseline_smoothed'][:ja] = '小売・娯楽施設の人流(7日平均, %)'
$y0s['grocery_and_pharmacy_percent_change_from_baseline_smoothed'][:ja] = '食料品店の人流(7日平均, %)'
$y0s['parks_percent_change_from_baseline_smoothed'][:ja] = '公園の人流(7日平均, %)'
$y0s['transit_stations_percent_change_from_baseline_smoothed'][:ja] = '駅の人流(7日平均, %)'
$y0s['workplaces_percent_change_from_baseline_smoothed'][:ja] = '職場の人流(7日平均, %)'
$y0s['residential_percent_change_from_baseline_smoothed'][:ja] = '住宅地の人流(7日平均, %)'

$atleast = nil
$keys.each do |key|
    if $cgi[key] == 'true'
        $atleast = true
        $y0s[key][:sel] = 'checked'
    end
end
if ! $atleast
    $y0s['new_cases_smoothed_per_million'][:sel] = 'checked'
    $y0s['new_deaths_smoothed_per_million'][:sel] = 'checked'
    $y0s['total_boosters_per_hundred'][:sel] = 'checked'
end

#
# iFrame
#
$iframeflag = false
if $cgi['i'] =~ /true|yes|on|1/
    $iframeflag = true
end

#
# Bar
#
$barflag = true
if $cgi['bar'] =~ /false|no|off|0/
    $barflag = false
end

#
# to Option
#
#$to = Date.today
$to = Date.parse('2023-05-08')
begin
    to = Date.parse($cgi['to'])
    $to = to if to >= Date.parse('2020-03-01')
rescue
end
$to_y = $to.strftime('%Y').to_i
$to_M = $to.strftime('%b')
$to_m = $to.strftime('%m').to_i
$to_d = $to.strftime('%d').to_i
#$to_d = ($to + 1).strftime('%d').to_i # XXX


$cto = $to
begin
    cto = Date.parse($cgi['cto'])
    $cto = cto if cto >= Date.parse('2020-03-01')
rescue
end

#
# from Option
#
$from = Date.parse('2020-01-01')
begin
    from = Date.parse($cgi['from'])
    $from = from if Date.parse('1980-01-01') <= from && from < $to
rescue
end
$from_y = $from.strftime('%Y').to_i
$from_M = $from.strftime('%b')
$from_m = $from.strftime('%m').to_i
$from_d = $from.strftime('%d').to_i

$cfrom = $from
begin
    cfrom = Date.parse($cgi['cfrom'])
    $cfrom = cfrom if Date.parse('1980-01-01') <= cfrom && cfrom < $cto
rescue
end

$oldest_year = $from_y
#$start_year = $start_year < $from_y ? $from_y : $start_year
$start_year = $from_y

if $to - $from >= 365
    $xtitle = "#{$from_y}/#{$from_m}-#{$to_y}/#{$to_m}"
    $xtitle += " (#{{ja: '年/月', en: 'Year/Month'}[$l]})"
    $xaxis =  "%Y/%m"
else
    $xtitle = "#{$from_y}/#{$from_m}/#{$from_d}-#{$to_y}/#{$to_m}/#{$to_d}"
    $xtitle += " (#{{ja: '年/月/日', en: 'Year/Month/Date'}[$l]})"
    $xaxis =  "%Y/%m/%d"
end

#
# Two check
#
$tcheck = ''
if $cgi['two'] == 'true'
    $tcheck = 'checked'
end

print_header(:title => ($l == :ja ?
                            "新型コロナの感染状況(多種データ比較)" :
                            "COVID19 Infection Status (Various Data Comparison)"),
             :iframe => $iframeflag)

if ! $iframeflag
    print <<EOF
  <p class=l>
  <form action="infect.rb" method="get" style="text-align: center;">
     #{{ja: '国・地域 (最大', en: 'Countries and/or locations (Max'}[$l]}#{$max_codes})
    <input type="text" name="c" value="#{$init_locs}" size="60" placeholder="#{$pholder}"/>
    #{{ja:'開始日',en:'From'}[$l]} <input type="text" name="from" value="#{$from}" size="10"/>
    #{{ja:'終了日',en:'To'}[$l]} <input type="text" name="to" value="#{$to}" size="10"/><br>
    <details>
      <summary>#{{ja: 'チェックボックス展開', en: 'Expand Checkboxes'}[$l]}</summary>
EOF

    $y0s.each do |k, y|

        k2 = k.gsub(/_per_.*$/,'')
        next if k !~ /smoothed/ && $y0s.find{|k3, y3| k3 =~ /#{k2}_smoothed/}

        print <<EOF
    <span><input type="checkbox" name="#{k}" value="true" #{y[:sel]}> #{y[$l]}</span>
EOF
    end

    print <<EOF
   </details>
    <input type="checkbox" name="two" value="true" #{$tcheck}>
    #{{ja: '2軸比較', en: 'Two axes comparison'}[$l]}
    <input type="radio" name="l" value="ja" #{$jcheck}>日本語
    <input type="radio" name="l" value="en" #{$echeck}>English
    <input type="submit" value="送信/submit" />
    <input type="hidden" name="i" value="#{$iframeflag}">
  </form>
EOF
end

should = []
source = ['date', 'week', 'location']
$codes.each do | code |
    loc = $locs[code]
    je = (code =~ /^jp-/) ? :ja : :en
    should.push({'term' => {'location.keyword' => $locs[code][je]}})
end
$y0s.each do |k, v|
    if v[:sel] == ''
        next
    end
    source.push(v[:name])
    source.push(v[:calc]) if v[:name] != v[:calc]
end

data = elastic_search(
    :index => 'covid19',
    :filter => [{'range' => {'date' => {'gte' => "#{$from.to_s}", 'lte' => "#{$to.to_s}"}}}],
    :should => should,
    :source => source,
    #:debug => 'SHOWONLY',
)

#
# translation
#
$locations = Array.new
prev_loc = nil
totals = {}
data.each do |datum|
    datum.transform_keys!(&:to_s)
    if $l == :ja && datum['_id'] !~ /^jp-/
        k = $locs_r[datum['location']]
        if k != nil
            if $locs[k][:ja] != ''
                datum['location'] = $locs[k][:ja]
            end
        end
    elsif $l == :en && datum['_id'] =~ /^jp-/
        k = $locs_r[datum['location']]
        if k != nil
            datum['location'] = $locs[k][:en]
        end
    end

    datum['date'] = Date.parse(datum['date'])

    $locations.push(datum['location']) if ! $locations.include?(datum['location'])
end
$locations.sort!

#
# reverse fill
#
$hash0 = Hash[data.map {|datum| [datum['_id'], datum]}]
$codes.each do |code|
    #pp code
    $keys.each do |key|
        next if key !~ /^total_.*(vaccinations|boosters|dose|)/ ||$y0s[key][:sel] != 'checked'
        #pp key
        value = -1
        ($from..$to).reverse_each do |date|
            id = "#{code}-#{date}"
            id2 = "#{code}-#{date-1}"
            #pp id
            next if ! $hash0[id]
            if value < 0
                if $hash0[id][key].to_f > 0
                    value = $hash0[id][key].to_f
                else
                    next
                end
            end
            next if ! $hash0[id2]
            if $hash0[id2][key].to_f == value
                $hash0[id][key] = nil
            end
        end
    end
end

#
# Total all causes
#
if $y0s['total_all_cause_deaths_smoothed'][:sel] == 'checked' ||
   $y0s['total_all_cause_deaths_smoothed_per_million'][:sel] == 'checked'

    # sort
    data.sort!{|a, b| [a['location'], a['date']] <=>
               [b['location'], b['date']]}

    # sum
    #start = Date.parse('2020-03-01')
    start = $from
    data.each do |datum|
        ['total_all_cause_deaths_smoothed',
         'total_all_cause_deaths_smoothed_per_million'].each do |key|
            next if datum['date'] < start || ! datum[key.gsub(/^total_/,'')]
            if prev_loc != datum['location']
                totals['total_all_cause_deaths_smoothed'] = 0
                totals['total_all_cause_deaths_smoothed_per_million'] = 0
                prev_loc = datum['location']
            end
            totals[key] += datum[key.gsub(/^total_/,'')].to_f
            datum[key] = totals[key].round(2)
        end
    end
end

['total_all_cause_deaths_smoothed',
 'total_all_cause_deaths_smoothed_per_million'].each do |key|
    $y0s[key][:calc] = key
end

$y0s.each do |k, y|
    (min, max) = data.minmax {|a, b| a[y[:calc]].to_f<=>b[y[:calc]].to_f}
    y[:min] = min[y[:calc]].to_f
    y[:min] = (y[:min] > 0) ? 0 : y[:min] * 1.1
    y[:max] = max[y[:calc]].to_f * 1.1
    y[:max] = 5 if k == 'reproduction_rate' && y[:max] > 5
    y[:max] = 2 if k == 'positive_rate' && y[:max] > 2
    if $codes.find{|code| code == 'IND'}
        y[:max] = 50 if k =~ /per_world$/ && y[:max] > 50
    else
        y[:max] = 20 if k =~ /per_world$/ && y[:max] > 20
    end
    y[:max] = 1000 if k == 'tests_per_case' && y[:max] > 1000

    if $cgi["#{k}_max"] && $cgi["#{k}_max"] != '' &&
       ($cgi["#{k}_max"].to_i.kind_of?(Integer) || $cgi["#{k}_max"].to_i.kind_of?(Float))
        y[:max] = $cgi["#{k}_max"].to_i
    end
end

# adjust max
ys = $y0s.select{|k, v| k =~ /(doses|vaccinations)_.*smoothed$/ && v[:sel] == 'checked'}
y_max = ys.to_a.max{|a, b| a[1][:max]<=>b[1][:max]}
ys.each do |k, v|
    v[:max] = y_max[1][:max]
end

ys = $y0s.select{|k, v| k =~ /per_hundred/ && v[:sel] == 'checked'}
y_max = ys.to_a.max{|a, b| a[1][:max]<=>b[1][:max]}
ys.each do |k, v|
    v[:max] = y_max[1][:max]
end


# adjust max per million
ys = $y0s.select{|k, v| k =~ /(doses|vaccinations)_.*smoothed_per_million$/ && v[:sel] == 'checked'}
y_max = ys.to_a.max{|a, b| a[1][:max]<=>b[1][:max]}
ys.each do |k, v|
    v[:max] = y_max[1][:max]
end

# Type 1形式の感染統計グラフを出力する。
# Render infection statistics using the Type 1 chart layout.
def print_type1(data)
    print <<EOF
  <p class=l>
  <div id="vis" style="width:#{$width};">
  <span id="blink1223" style="font-size: large; font-weight: bold;">#{{ja: '読込中...', en: 'Now Loading...'}[$l]}</span><script>with(blink1223)id='',style.opacity=1,setInterval(function(){style.opacity^=1},500)</script>
  </div>
  <script>
    const spec = {
      "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
      "config": {
        "title": {"fontSize": 15},
        "axis": {"titleFontSize": 14, "labelFontSize": 14},
        "legend": {"titleFontSize": 14, "labelFontSize": 14}
      },
EOF
    if $barflag
        print <<EOF
      "params": [
        {
          "name": "start_year",
          "value": #{$start_year},
          "bind": {"input": "range", "min": #{$oldest_year}, "max": 2023, "step": 1 }
        }
      ],
EOF
        $start_year2 = '"start_year"'
    else
        $start_year2 = $start_year
    end
    print <<EOF
      "data": {
EOF
    print '        "values": '

puts JSON.pretty_generate(data).gsub(/\n/, "\n        ")

print <<EOF
      },
      "vconcat": [
EOF

    firstflag = true
    $y0s.each do |k, v|
        if v[:sel] == ''
            next
        end
        if firstflag
            firstflag = false
        else
            puts ','
        end
        if $l == :ja
            title = "#{v[$l]}"
        else
            title = "#{v[$l]}"
        end
        print <<EOF
        {
          "title": {
            "text": "#{title}",
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "transform": [
            {
              "filter": {
                "field": "date",
                "range": [
                  {"year": #{$from_y}, "month": "#{$from_M}", "date": #{$from_d}},
                  {"year": #{$to_y},   "month": "#{$to_M}",   "date": #{$to_d}}
                ]
              }
            },
            { "filter": "datum.#{v[:name]} != null" }
          ],
          "encoding": {
            "x": {
              "title": "#{$xtitle}",
              "field": "date",
              "type": "temporal",
              "timeUnit": "yearmonthdate",
              "axis": {"format": "#{$xaxis}"},
              "scale": {
                "domain": [
                  {"year": #{$start_year2}, "month": "#{$from_M}", "date": #{$from_d}},
                  {"year": #{$to_y},   "month": "#{$to_M}",   "date": #{$to_d}}
                ]
              }
            }
          },
          "layer": [
            {
              "mark": {"type": "line", "clip": true},
              "params": [
                {
                  "name": "loc",
                  "select": {
                    "type": "point",
                    "fields": ["location"]
                  },
                  "bind": {"legend": "mouseover"}
                }
              ],
              "encoding": {
                "y": {
                  "field": "#{v[:name]}",
                  "type": "quantitative",
                  "aggregate": "average",
                  "scale": {"domain": [#{v[:min]}, #{v[:max]}]},
                  "axis": {"title": ""}
                },
                "color": {
                  "title": "#{{ja: '国/地域', en: 'Country/Area'}[$l]}",
                  "field": "location",
                  "scale": { "scheme": "dark2" }
                },
                "strokeDash": {"field": "location", "type": "nominal"},
                "opacity": {
                  "condition": {"param": "loc", "value": 1},
                  "value": 0.1
                }
              }
            },
            {
              "transform": [
                {
                  "pivot": "location",
                  "value": "#{v[:name]}",
                  "groupby": ["date"]
                }
              ],
              "mark": "rule",
              "encoding": {
                "opacity": {
                  "condition": {"value": 0.3, "param": "hover", "empty": false},
                  "value": 0
                },
                "tooltip": [
EOF
        $locations.each do |l|
            print <<EOF
                  {"field": "#{l}", "type": "quantitative"},
EOF
        end
        print <<EOF
                  {"title": "#{{:ja=>"年/月/日", :en=>"Year/Month/Date"}[$l]}",
                   "timeUnit": "yearmonthdate",
                   "field": "date", "format": "%Y/%m/%d" }
                ]
              },
              "params": [
                {
                  "name": "hover",
                  "select": {
                    "type": "point",
                    "fields": ["date"],
                    "nearest": true,
                    "on": "mouseover",
                    "clear": "mouseout"
                  }
                }
              ]
            }
          ]
EOF
        print '        }'
    end

    puts
    print <<EOF
      ]
    };
    vegaEmbed("#vis", spec, {mode: "vega-lite"}).then(console.log).catch(console.warn);
  </script>
EOF

end

# Type 2形式の感染統計グラフを出力する。
# Render infection statistics using the Type 2 chart layout.
def print_type2(data)
    y1s = $y0s.select{|k, y| y[:sel] == 'checked' && k !~ /vacc|booster|doses|baseline/}
    y2s = $y0s.select{|k, y| y[:sel] == 'checked' && k =~ /vacc|booster|doses|baseline/}

    k = 1
    y2s.each do |k2, y2|
        y2title = $height <= 150 ? '' : y2[$l]

        y1s.each do |k1, y1|
            y1title = $height <= 150 ? '' : y1[$l]

            print <<EOF
  <p class=l>
  <div id="vis#{k}" style="width:80%;">
  <span id="blink1223" style="font-size: large; font-weight: bold;">#{{ja: '読込中...', en: 'Now Loading...'}[$l]}</span><script>with(blink1223)id='',style.opacity=1,setInterval(function(){style.opacity^=1},500)</script>
  </div>
  <script>
    var spec#{k} = {
      "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
      "config": {
        "title": {"fontSize": 15},
        "axis": {"titleFontSize": 14, "labelFontSize": 14},
        "legend": {"titleFontSize": 14, "labelFontSize": 14}
      },
EOF
    if $barflag
        print <<EOF
      "params": [
        {
          "name": "start_year",
          "value": #{$start_year},
          "bind": {"input": "range", "min": #{$oldest_year}, "max": 2023, "step": 1 }
        }
      ],
EOF
        $start_year2 = '"start_year"'
    else
        $start_year2 = $start_year
    end
    print <<EOF
      "data": {
EOF
            print '        "values": '

            puts JSON.pretty_generate(data).gsub(/\n/, "\n        ")

            print <<EOF
      },
      "vconcat": [
EOF
            firstflag = true
            $codes.each do |code|

                if firstflag
                    firstflag = false
                else
                    puts ','
                end

                # correlation_coefficient
                data2 = data.select{|i|  i['location'] == $locs[code][$l]}
                a = Array.new
                b = Array.new
                data2.each do |datum|
                    if datum[y1[:name]] != nil &&
                       datum[y1[:name]] != '' &&
                       datum[y2[:name]] != nil &&
                       datum[y2[:name]] != '' &&
                       datum['date'] <= $cto &&
                       datum['date'] >= $cfrom
                        next if y1[:name] =~ /excess|all_cause/ &&
                                (!datum['week'] || datum['week'] == '')
                        a.push(datum[y1[:name]].to_i)
                        b.push(datum[y2[:name]].to_i)
                    end
                end
                r = (a != [] && b != []) ?
                        sprintf('%.2f', correlation_coefficient(a, b)) : 'NaN'

                # title
                if $l == :ja
                    title = "#{$locs[code][$l]}の#{y1[$l]}と#{y2[$l]} (r=#{r})"
                else
                    title = "#{y1[$l]} and #{y2[$l]} in #{$locs[code][$l]} (r=#{r})"
                end
                if $cto != $to || $from != $cfrom
                    title.sub!(/\(r=(.*)\)/, '(r=\1 ' +
                               "#{$cfrom.strftime("%Y/%m/%d")}-#{$cto.strftime("%Y/%m/%d")})")
                end

                print <<EOF
        {
          "title": {
            "text": "#{title}",
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "transform": [
            {
              "filter": {
                "field": "date",
                "range": [
                  {"year": #{$from_y}, "month": "#{$from_M}", "date": #{$from_d}},
                  {"year": #{$to_y}, "month": "#{$to_M}", "date": #{$to_d}}
                ]
              }
            },
            { "filter": "datum.location == \'#{$locs[code][$l]}\'" }
          ],
          "encoding": {
            "x": {
              "title": "#{$xtitle}",
              "field": "date",
              "type": "temporal",
              "timeUnit": "yearmonthdate",
              "axis": {"format": "#{$xaxis}"},
              "scale": {
                "domain": [
                  {"year": #{$start_year2}, "month": "#{$from_M}", "date": #{$from_d}},
                  {"year": #{$to_y}, "month": "#{$to_M}", "date": #{$to_d}}
                ]
              }
            }
          },
          "resolve": {"scale": {"y": "independent"}},
          "layer": [
            {
              "mark": {"type": "bar", "color": "#ff4500", "clip": true, "binSpacing": 0},
              "encoding": {
                "y": {
                  "title": "#{y1title}",
                  "field": "#{y1[:name]}",
                  "type": "quantitative",
                  "aggregate": "average",
                  "scale": {"domain": [#{y1[:min]}, #{y1[:max]}]},
                  "axis": {"grid": true}
                },
                "tooltip": {"field": "#{y1[:name]}", "type": "quantitative"}
              }
            },
            {
              "mark": {"type": "line", "color": "#0000ff", "clip": true},
              "encoding": {
                "y": {
                  "title": "#{y2title}",
                  "field": "#{y2[:name]}",
                  "type": "quantitative",
                  "aggregate": "average",
                  "scale": {"domain": [#{y2[:min]}, #{y2[:max]}]}
                },
                "tooltip": {"field": "#{y2[:name]}", "type": "quantitative"}
              }
            },
            {
              "mark": "rule",
              "encoding": {
                "opacity": {
                  "condition": {"value": 0.3, "param": "hover", "empty": false},
                  "value": 0
                },
                "tooltip": [
                  {"title": "#{y1[$l]}", "field": "#{y1[:name]}", "type": "quantitative"},
                  {"title": "#{y2[$l]}", "field": "#{y2[:name]}", "type": "quantitative"},
                  {"title": "#{{:ja=>"年/月/日", :en=>"Year/Month/Date"}[$l]}",
                   "timeUnit": "yearmonthdate",
                   "field": "date", "format": "%Y/%m/%d" }
                ]
              },
              "params": [
                {
                  "name": "hover",
                  "select": {
                    "type": "point",
                    "fields": ["date"],
                    "nearest": true,
                    "on": "mouseover",
                    "clear": "mouseout"
                  }
                }
              ]
            }
          ]
EOF
                print '        }'
            end
            puts
            print <<EOF
      ]
    };
    vegaEmbed("#vis#{k}", spec#{k}, {mode: "vega-lite"}).then(console.log).catch(console.warn);
  </script>
EOF
            k += 1
        end
    end
end

if $tcheck != 'checked'
    print_type1(data)
else
    print_type2(data)
end

if $iframeflag == false
    print <<EOF
  <p class=r>
    © 2022 <a href="https://medicalfacts.info">MedicalFacts.info</a> powered by <a href="https://www.elastic.co/" target><img src="https://images.contentstack.io/v3/assets/bltefdd0b53724fa2ce/blt280217a63b82a734/5bbdaacf63ed239936a7dd56/elastic-logo.svg" style="height: 2em"></a> <a href="https://vega.github.io/vega-lite/" style="text-decoration: none;"><img src="https://raw.githubusercontent.com/vega/logos/master/assets/VL_Color%40128.png" style="width: 2em;"> Vega-Lite</a>
  <hr>
  <p class=l>
    #{{ja: 'データ元', en: 'Data sources'}[$l]}:
    <ul>
      <li> <a href="https://covid.ourworldindata.org/data/owid-covid-data.csv">https://covid.ourworldindata.org/data/owid-covid-data.csv</a>
      <li> <a href="https://github.com/nytimes/covid-19-data/raw/master/us-states.csv">https://github.com/nytimes/covid-19-data/raw/master/us-states.csv</a>
      <li> <a href="https://www.usmortality.com/">https://www.usmortality.com/</a>
      <li> <a href="https://www3.nhk.or.jp/n-data/opendata/coronavirus/nhk_news_covid19_prefectures_daily_data.csv">https://www3.nhk.or.jp/n-data/opendata/coronavirus/nhk_news_covid19_prefectures_daily_data.csv</a>
      <li> <a href="https://exdeaths-japan.org/data/Observed.csv">https://exdeaths-japan.org/data/Observed.csv</a>
      <li> <a href="https://www.mortality.org/Public/STMF/Inputs/STMFinput.zip">https://www.mortality.org/Public/STMF/Inputs/STMFinput.zip</a>
      <li> <a href="https://www.gstatic.com/covid19/mobility/Global_Mobility_Report.csv">https://www.gstatic.com/covid19/mobility/Global_Mobility_Report.csv</a>
      <li> <a href="https://data.vrs.digital.go.jp/vaccination/opendata/latest/prefecture.ndjson">https://data.vrs.digital.go.jp/vaccination/opendata/latest/prefecture.ndjson</a>
    </ul>
  </div>
EOF
end

print <<EOF
</body>
</html>
EOF
