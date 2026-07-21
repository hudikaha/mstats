#!/usr/bin/ruby
# coding: utf-8

require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require 'date'
require './c19db'

mfacts = [
    File.expand_path('../lib/mfacts.rb', __dir__),
    File.expand_path('lib/mfacts.rb', __dir__)
].find { |path| File.file?(path) }
abort 'lib/mfacts.rb not found' unless mfacts
require mfacts

#
# CGI and cache
#
$cgi = CGI.new
#Output.console_and_cache("cache/vaxx.rb?" + $cgi.params.join('=', '&'))

#
# Language
#
lang = $cgi['l']
$echeck = ''
$jcheck = ''
if (lang != '' && /^#{lang}/ =~ 'english') ||
   (lang == '' && ENV['HTTP_ACCEPT_LANGUAGE'] !~ /^ja/)
    $l    = :en
    $echeck = 'checked'
else
    $l    = :ja
    $jcheck = 'checked'
end

#
# Continents
#
$conts = {
    'All' => {
        en: 'All',
        ja: '全て',
        sel:  '',
        wid: '80%',
        col: 1,
    },
    'Africa' => {
        en: 'Africa',
        ja: 'アフリカ',
        sel:  '',
        wid: '70%',
        col: 2,
    },
    'Asia' => {
        en: 'Asia',
        ja: 'アジア',
        sel:  '',
        wid: '70%',
        col: 2,
    },
    'Europe' => {
        en: 'Europe',
        ja: 'ヨーロッパ',
        sel:  '',
        wid: '70%',
        col: 2,
    },
    'North America' => {
        en: 'North America',
        ja: '北アメリカ',
        sel:  '',
        wid: '80%',
        col: 1,
    },
    'Oceania' => {
        en: 'Oceania',
        ja: 'オセアニア',
        sel:  '',
        wid: '80%',
        col: 1,
    },
    'South America' => {
        en: 'South America',
        ja: '南アメリカ',
        sel:  '',
        wid: '80%',
        col: 1,
    },
    'USA' => {
        en: 'USA',
        ja: '米国',
        sel:  '',
        wid: '70%',
        col: 2,
    },
    'Japan'=> {
        en: 'Japan',
        ja: '日本',
        sel:  '',
        wid: '80%',
        col: 2,
    },
}

$ckey = $cgi['c']
$cont = $conts[$ckey]
if !$cont
    $ckey = 'All'
    $cont = $conts[$ckey]
end

$cont[:sel] = 'selected'

#
# Infection
#
$infs = {
    'cases' => {
        name: 'new_cases_smoothed_per_million',
        calc: 'new_cases_smoothed_per_million',
        ja:   '100万人当り陽性者数(7日平均)',
        en:   'Cases per million pop (7day avg)',
        max:  0,
        min:  0,
        sel:  '',
    },
    'cases2' => {
        name: 'new_cases_smoothed',
        calc: 'new_cases_smoothed',
        ja:   '陽性者数(7日平均、絶対数)',
        en:   'Cases (7day avg, absolute)',
        max:  0,
        min:  0,
        sel:  '',
    },
    'deaths' => {
        name: 'new_deaths_smoothed_per_million',
        calc: 'new_deaths_smoothed_per_million',
        ja:   '100万人当り死者数(7日平均)',
        en:   'Deaths per million pop (7day avg)',
        max:  0,
        min:  0,
        sel:  '',
    },
    'deaths2' => {
        name: 'new_deaths_smoothed',
        calc: 'new_deaths_smoothed',
        ja:   '死者数(7日平均、絶対数)',
        en:   'Deaths per million pop (7day avg, absolute)',
        max:  0,
        min:  0,
        sel:  '',
    },
    'excess' => {
        name: 'excess_mortality',
        calc: 'excess_mortality',
        ja:   '超過死亡率(%)',
        en:   'Excess mortality(%)',
        max:  0,
        min:  0,
        sel:  '',
    },
    'excess_c' => {
        name: 'excess_mortality_cumulative',
        calc: 'excess_mortality_cumulative',
        ja:   '累積超過死亡率',
        en:   'Excess mortality cumulative',
        max:  0,
        min:  0,
        sel:  '',
    },
}

#
# iFrame
#
$iframeflag = $cgi['i']
if $iframeflag == '1' || $iframeflag == 'true'
    $iframeflag = true
else
    $iframeflag = false
end

#
# Vaxx
#
$vaxxs = {
    'full' => {
        name: 'people_fully_vaccinated_per_hundred',
        calc: 'people_fully_vaccinated_per_hundred',
        ja:   '2回目接種数率(%)',
        en:   'People fully vaxx(%)',
        max:  0,
        min:  0,
        sel:  '',
    },
    'booster' => {
        name: 'total_boosters_per_hundred',
        calc: 'total_boosters_per_hundred',
        ja:   'ブースター(追加)接種率(%)',
        en:   'Total boosters(%)',
        max:  0,
        min:  0,
        sel:  '',
    },
    'doses' => {
        name: 'total_vaccinations_per_hundred',
        calc: 'total_vaccinations_per_hundred',
        ja:   '100人当り接種数累計',
        en:   'Total doses per 100 pop',
        max:  0,
        min:  0,
        sel:  '',
    },
    '3doses' => {
        name: 'total_3doses_per_hundred',
        calc: 'total_3doses_per_hundred',
        ja:   '3回目接種率(%)',
        en:   '3rd doses per 100 pop',
        max:  0,
        min:  0,
        sel:  '',
    },
    '4doses' => {
        name: 'total_4doses_per_hundred',
        calc: 'total_4doses_per_hundred',
        ja:   '4回目接種率(%)',
        en:   '4th doses per 100 pop',
        max:  0,
        min:  0,
        sel:  '',
    },
    '3doses65over' => {
        name: 'total_3doses_65over_per_hundred',
        calc: 'total_3doses_65over_per_hundred',
        ja:   '3回目接種率(65歳以上、%)',
        en:   '3rd doses per 100 pop (65over)',
        max:  0,
        min:  0,
        sel:  '',
    },
    '4doses65over' => {
        name: 'total_4doses_65over_per_hundred',
        calc: 'total_4doses_65over_per_hundred',
        ja:   '4回目接種率(65歳以上、%)',
        en:   '4th doses per 100 pop (65over)',
        max:  0,
        min:  0,
        sel:  '',
    },
}

$vkey = $cgi['v']
if $vkey == '2'
    $vkey = 'full'
elsif $vkey == '3'
    $vkey = 'booster'
end

$vaxx = $vaxxs[$vkey]
if ! $vaxx
    $vkey = 'booster'
    $vaxx = $vaxxs[$vkey]
end
$vaxx[:sel] = 'selected'

#
# Date
#
before = ($cgi['b'].to_i > 0) ? $cgi['b'].to_i : 3
begin
    $date = Date.parse($cgi['d'])
rescue
    #$date = Date.today - before
    $date = Date.parse('2023-01-23')
end

$date = $date < Date.parse('2021-03-01') ? Date.parse('2021-03-01') : $date

#pp $date.to_s
#exit

$days = 90
if $cgi['days'] && 90 < $cgi['days'].to_i && $cgi['days'].to_i <= 365
    $days = $cgi['days'].to_i
end
$datestr = $date.to_s
$before = 'before_' + $datestr.gsub(/-/, '_')
$datestr2 = ($date - $days).to_s

#
#  excess
#
$statuses = []
if $cgi['c1'] == 'true'
    $statuses += ['cases']
    $infs['cases'][:sel] = 'checked'
end
if $cgi['c2'] == 'true'
    $statuses += ['cases2']
    $infs['cases2'][:sel] = 'checked'
end
if $cgi['d1'] == 'true'
    $statuses += ['deaths']
    $infs['deaths'][:sel] = 'checked'
end
if $cgi['d2'] == 'true'
    $statuses += ['deaths2']
    $infs['deaths2'][:sel] = 'checked'
end
if $cgi['e'] == 'true'
    $statuses += ['excess']
    $infs['excess'][:sel] = 'checked'
end
if $cgi['ec'] == 'true'
    $statuses += ['excess_c']
    $infs['excess_c'][:sel] = 'checked'
end

if $statuses == []
    $statuses = ['cases', 'deaths']
    $infs['cases'][:sel] = 'checked'
    $infs['deaths'][:sel] = 'checked'
end

#
# Height
#
if $statuses.count == 1
    $height = 400
else
    $height = 250
end
$height = ($cgi['height'] != '' && $cgi['height'].to_i >= 100) ? $cgi['height'].to_i : $height

#
# Width
#
$width = ($cgi['width'] != '') ? $cgi['width'] : $cont[:wid]

#
# Y Max Term
#
$ymaxterm == ''
if $cgi['ymaxterm'] == 'true'
    $ymaxterm = 'checked'
end

title = {ja: 'ワクチン接種率と新型コロナ感染状況',
         en: 'Vaccination Share and COVID-19 Infection Status'}[$l]
print_header(title: title, iframe: $iframeflag)

if $iframeflag == false
    print <<EOF
  <h3 style="text-align: center;">#{{ja: '下のスライドバーで時間遡行', en:'Go back in time by the slide bar below'}[$l]}</h3>
EOF

    print <<EOF
  <form action="vaxx.rb" method="get" style="text-align: center;">
  #{{ja: '大陸・国', en: 'Continent/Country'}[$l]}
  <select name="c">
EOF

    $conts.each do |k, v|
        print <<EOF
  <option value="#{k}" #{v[:sel]}>#{v[$l]}</option>
EOF
    end

    print <<EOF
  </select>
  #{{ja: '接種回',  en: 'Vaccination'}[$l]}
  <select name="v">
EOF

    $vaxxs.each do |k, v|
        print <<EOF
    <option value="#{k}" #{v[:sel]}>#{v[$l]}</option>
EOF
    end

    print <<EOF
  </select>
  #{{ja: '日付', en: 'Date'}[$l]}
    <input type="text" name="d" value="#{$datestr}" size="10" /><br>
    <input type="checkbox" name="c1" value="true" #{$infs['cases'][:sel]}>#{{ja: '陽性者', en: 'Cases'}[$l]}
    <input type="checkbox" name="c2" value="true" #{$infs['cases2'][:sel]}>#{{ja: '陽性者絶対数', en: 'Absolute cases'}[$l]}
    <input type="checkbox" name="d1" value="true" #{$infs['deaths'][:sel]}>#{{ja: '死者', en: 'Deaths'}[$l]}
    <input type="checkbox" name="d2" value="true" #{$infs['deaths2'][:sel]}>#{{ja: '死者絶対数', en: 'Absolute deaths'}[$l]}
    <input type="checkbox" name="e" value="true" #{$infs['excess'][:sel]}>#{{ja: '超過死亡率', en: 'Excess mortality'}[$l]}
<!--
    <input type="checkbox" name="ec" value="true" #{$infs['excess_c'][:sel]}>#{{ja: '累積超過死亡率', en: 'Excess mortality cumulative'}[$l]}
-->
    <input type="checkbox" name="ymaxterm" value="true" #{$ymaxterm}>#{{ja: 'Y軸最大値は期間をみる', en: 'Y-axis max is determined by the term'}[$l]}
    <input type="radio" name="l" value="ja" #{$jcheck}>日本語
    <input type="radio" name="l" value="en" #{$echeck}>English
    <input type="submit" value="送信/submit" />
    <input type="hidden" name="i" value="#{$iframeflag}">
  </form>
EOF
end

print <<EOF
  <p class=l>
  <div id="vis" style="width: #{$width};">
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
      "params": [
        {
          "name": "grid",
          "select": "interval",
          "bind": "scales"
        },
        {
          "name": "days",
          "select": {"type": "point", "fields": ["#{$before}"]},
          "value": 0,
          "bind": {
            "#{$before}": {"input": "range", "min": -#{$days},"max": 0,"step": 1}
          }
        },
        {
          "name": "loc",
          "select": {
            "type": "point",
EOF
if $ckey == 'All'
    print <<EOF
            "fields": ["continent"]
EOF
else
    print <<EOF
            "fields": ["location"]
EOF
end
print <<EOF
          },
          "bind": {"legend": "mouseover"}
        }
      ],
      "transform": [
EOF
if $ckey == 'Japan'
    print <<EOF
        {
          "filter": "datum._source.location != '東京+大阪'"
        },
EOF
elsif $ckey == 'USA'
else
    print <<EOF
        {
          "filter": "datum._source.continent != null"
        },
EOF
end
print <<EOF
        {
          "calculate": "datum._source.continent",
          "as": "continent"
        },
        {
          "calculate": "datum._source.location",
          "as": "location"
        },
        {
          "calculate": "datum._source.days_before",
          "as": "#{$before}"
        }
      ],
      "data": {
EOF

uri = URI.parse("http://localhost:8080/elastic/covid19/_search")
request = Net::HTTP::Get.new(uri)
request.content_type = "application/json"
request.body = <<EOF
{
  "size": 100000,
  "query": {
    "bool": {
      "must": [
        { "range": {"date": {"gte": "#{$datestr2}", "lte": "#{$datestr}" } } },
        {
          "bool": {
            "should": [
EOF

if $ckey == 'All'
    request.body += <<EOF
              { "term": {"continent.keyword": "Africa"} },
              { "term": {"continent.keyword": "Asia"} },
              { "term": {"continent.keyword": "Europe"} },
              { "term": {"continent.keyword": "North America"} },
              { "term": {"continent.keyword": "Oceania"} },
              { "term": {"continent.keyword": "South America"} }
EOF
elsif $ckey == 'USA'
    request.body += <<EOF
              { "term": {"tags.keyword": "us"} }
EOF
elsif $ckey == 'Japan'
    request.body += <<EOF
              { "term": {"tags.keyword": "jp"} }
EOF
else
    request.body += <<EOF
              { "term": {"continent.keyword": "#{$ckey}"} }
EOF
end
request.body += <<EOF
            ]
          }
        }
      ]
    }
  },
  "_source": [
EOF
[$infs, $vaxxs].each do |y|
    y.each do |k, v|
        request.body +=  <<EOF
    "#{v[:name]}",
EOF
    end
end
request.body += <<EOF
    "date",
    "iso_code",
    "location",
    "continent"
  ]
}
EOF

# HTTP request
response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
end

data = JSON.parse(response.body)['hits']['hits']
data.delete_if{|datum| datum['_source']['location'] == '東京+大阪'}

# JP <-> EN translation && fill
#prev_location = nil
#prev_vaxxs = Hash.new
data.each do |datum|
    if $l == :ja && datum['_id'] !~ /^jp-/
        k = $locs_r[datum['_source']['location']]
        if k != nil
            if $locs[k][:ja] != ''
                datum['_source']['location'] = $locs[k][:ja]
            end
        end
        cont = $conts[datum['_source']['continent']]
        if cont != nil
            datum['_source']['continent'] = cont[:ja]
        end
    elsif $l == :en && datum['_id'] =~ /^jp-/
        k = $locs_r[datum['_source']['location']]
        if k != nil
            datum['_source']['location'] = $locs[k][:en]
        end
    end
#
#    if datum['_source']['location'] == prev_location
#        $vaxxs.each do |k, vaxx|
#            if ! datum['_source'][vaxx[:name]] && prev_vaxxs[vaxx[:name]]
#                datum['_source'][vaxx[:name]] = prev_vaxxs[vaxx[:name]]
#                pp k
#                pp datum
#                exit
#            else
#                prev_vaxxs[vaxx] = datum['_source'][vaxx[:name]]
#            end
#        end
#    end
#    prev_location = datum['_source']['location']
#    if datum['_source']['location'] == 'Japan'
#        pp datum
#    end
end

# MIN MAX
$clipflag = false
[$vaxxs, $infs].each do |x|
    x.each do |k, y|
        min_val = 0.0
        max_val = 0.0
        data2 = data.select {|datum| datum['_source'][$vaxxs[$vkey][:calc]]}
        if $ckey != 'Japan' && $ckey != 'USA'
            data2 = data2.select {|datum|
                datum['_source']['iso_code'] &&
                    $pops["#{datum['_source']['iso_code']}-2022"] &&
                    $pops["#{datum['_source']['iso_code']}-2022"] > 5000000
            }
        end
        if $ymaxterm != 'checked'
            data2 = data2.select {|datum|
                datum['_source']['date'] == $datestr
            }
        end
        max = data2.max {|a, b|
            a['_source'][y[:calc]].to_f <=> b['_source'][y[:calc]].to_f
        }
        max_val = max ? max['_source'][y[:calc]].to_f : 1
        y[:max] = max_val * 1.1
        min = data2.min {|a, b| a['_source'][y[:calc]].to_f <=> b['_source'][y[:calc]].to_f}
        min_val = min ? min['_source'][y[:calc]].to_f : 0
        if k == 'excess' && min_val < 0
            y[:min] = min_val * 1.1
        else
            y[:min] = -(max_val * 0.03)
        end
        #pp k, max
    end
end

#pp $infs
#exit
#puts '+++++++++++++++++++++++++++'

{'cases' => $cgi['cmax'],
 'cases2' => $cgi['c2max'],
 'deaths' => $cgi['dmax'],
 'deaths2' => $cgi['d2max'],
 'excess' => $cgi['emax']}.each do |k, v|
    #pp k, v
    if v.to_i > 0
      $infs[k][:max] = v.to_i
    end
    $infs[k][:min] = -($infs[k][:max] * 0.02) if k != 'excess'
end

#$vaxx[:max] = 100 if $vkey == 'booster'
$vaxx[:max] = $cgi['vmax'].to_i if $cgi['vmax'].to_i > 0

#pp $vkey
#pp $vaxx[:max]
#exit

print '        "values": '

data.each do |datum|
    days_before = (Date.parse(datum['_source']['date']) - $date).to_i
    datum['_source']['days_before'] = days_before
    if datum['_id'] =~ /^us-/
        datum['_source']['continent'] = 'United States'
    end
end

puts JSON.pretty_generate(data).gsub(/\n/, "\n    ")
print <<EOF
      },
      "vconcat": [
EOF
firstflag = true
$statuses.each do |type|
    if firstflag
        firstflag = false
    else
        puts ','
    end
    $ytitle = $height >= 150 ? $infs[type][$l] : ''
print <<EOF
        {
          "title": {
            "text": "#{$vaxx[$l]}#{{ja: 'と', en: ' and '}[$l]}#{$infs[type][$l]}",
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "mark": {
            "type": "text",
            "fontWeight": "bold",
            "fontSize": "15"
          },
          "encoding": {
            "x": {
              "title": "#{$vaxx[$l]}",
              "field": "_source.#{$vaxx[:name]}",
              "type": "quantitative",
              "scale": { "domain": [ 0, #{$vaxx[:max]} ] }
            },
            "y": {
              "title": "#{$ytitle}",
              "field": "_source.#{$infs[type][:name]}",
              "type": "quantitative",
              "scale": { "domain": [ #{$infs[type][:min]}, #{$infs[type][:max]} ] }
            },
EOF
if $ckey == 'All'
    print <<EOF
            "color": {
              "title": "#{{ja: '大陸', en: 'Continent'}[$l]}",
              "field": "continent",
              "type": "nominal",
              "scale": { "scheme": "dark2" }
            },
EOF
else
    print <<EOF
            "color": {
              "title": "#{$cont[$l]}",
              "field": "location",
              "type": "nominal",
              "scale": { "scheme": "dark2" },
              "legend": {"symbolLimit": 200, "labelLimit": 120, "columns": #{$cont[:col]}}
            },
EOF
end
print <<EOF
            "text": {
              "condition": {
                "param": "days",
                "field": "location",
                "type": "nominal"
              }
            },
            "opacity": {
              "condition": {"param": "loc", "value": 1},
              "value": 0.1
            }
          }
EOF
print '        }'
end
print <<EOF
      ]
    };
    vegaEmbed("#vis", spec, {mode: "vega-lite"}).then(console.log).catch(console.warn);
  </script>
EOF

if $iframeflag == false
    print <<EOF
  <p class=r>
    © 2022 <a href="https://medicalfacts.info">MedicalFacts.info</a> powered by <a href="https://www.elastic.co/" target><img src="https://images.contentstack.io/v3/assets/bltefdd0b53724fa2ce/blt280217a63b82a734/5bbdaacf63ed239936a7dd56/elastic-logo.svg" style="height: 2em"></a> <a href="https://vega.github.io/vega-lite/" style="text-decoration: none;"><img src="https://raw.githubusercontent.com/vega/logos/master/assets/VL_Color%40128.png" style="width: 2em;"> Vega-Lite</a>
  <hr>
  <p class=l>
    #{{ja: 'データ元', en: 'Data sources'}[$l]}:
    <ul>
      <li> <a href="https://covid.ourworldindata.org/data/owid-covid-data.csv">https://covid.ourworldindata.org/data/owid-covid-data.csv</a>
      <li> <a href="https://github.com/owid/covid-19-data/raw/master/public/data/vaccinations/us_state_vaccinations.csv">https://github.com/owid/covid-19-data/raw/master/public/data/vaccinations/us_state_vaccinations.csv</a>
      <li> <a href="https://data.vrs.digital.go.jp/vaccination/opendata/latest/prefecture.ndjson">https://data.vrs.digital.go.jp/vaccination/opendata/latest/prefecture.ndjson</a>
      <li> <a href="https://www.usmortality.com/">https://www.usmortality.com/</a>
    </ul>
  </div>
</div>
EOF
end

print <<EOF
</body>
</html>
EOF
