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
# CGI
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
    $init_locs = 'ex) JPN,Sweden,Osaka,Israel,Florida,New York'
    $pholder = "Input country/state names and/or ISO-3-letter codes with ','"
else
    $l    = :ja
    $jcheck = 'checked'
    $init_locs = '例) JPN,Sweden,大阪,イスラエル,Florida,New York'
    $pholder = "国名(ISO 3文字可)や県名を「,」で区切って入力"
end

#
# Location and Start year
#
locs0 = $cgi['c'].gsub(/[、，]/,',')

if ! locs0 || locs0 == ''
    locs = $init_locs.gsub(/^例\) /, '').gsub(/^ex\) /,'').split(/[\~,\,:]/)
else
    locs = locs0.gsub(/^例\) /, '').gsub(/^ex\) /,'').split(/[\~,\,:]/)
end

$start_year0 = 2015
start_year = $start_year0

#
# to Option
#
$to = Date.today
begin
    to = Date.parse($cgi['to'])
    $to = to if to >= Date.parse('1980-12-31')
rescue
end
$to_y = $to.strftime('%Y').to_i
$to_m = $to.strftime('%b')
$to_d = $to.strftime('%d').to_i

$max_codes = 20
$codes = []
locs.each do |loc|
    loc2year = loc.to_i
    if $locs[loc]
        $codes.push(loc)
        next
    elsif 1980 <= loc2year && loc2year <= 2022
        start_year = loc2year
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
    if $codes.count >= $max_codes
        break
    end
end

init_locs0 = []
$codes.each do |code|
    init_locs0.push($locs[code][:en])
end

if locs0 && locs0 != ''
    $init_locs = init_locs0.join(',')
    if start_year != $start_year0
        $init_locs += ",#{start_year}"
    end
end

#
# The oldest year
#
oldest_year = $cgi['o']
if ! oldest_year || oldest_year == ''
        oldest_year = '1980'
end

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
# Height
#
$height = ($cgi['height'] != '' && $cgi['height'].to_i >= 100) ? $cgi['height'].to_i : 200

#
# Width
#
$width = ($cgi['width'] != '') ? $cgi['width'] : '90%'

title = {ja: '各国・各地域の全死因死亡率とコロナ死亡率',
         en: 'All-cause and COVID19 Mortality'}[$l]
print_header(title: title, iframe: $iframeflag)

if $iframeflag == false
    if $cgi['b'] == 'true'
        print <<EOF
  <div style="text-align: center;">
   <a href="https://songenshi-kyokai.or.jp/" target="_blank"><img src="https://songenshi-kyokai.or.jp/honbu/wp-content/uploads/2020/03/logo_w300.gif" border=1></a>
  </div>
  </div>
EOF
    end

    print <<EOF
  <h3 style="text-align: center;">#{{ja: '下のスライドバーで1980年から表示可能', en:'Plot graphs from 1980 by the slide bar below'}[$l]}</h3>
  <p class=l>
  <form action="mortality.rb" method="get" style="text-align: center;">
     #{{ja: '国・地域 (最大', en: 'Countries and/or locations (Max'}[$l]}#{$max_codes})
    <input type="text" name="c" value="#{$init_locs}" size="60" placeholder="#{$pholder}"/>
    <input type="radio" name="l" value="ja" #{$jcheck}>日本語
    <input type="radio" name="l" value="en" #{$echeck}>English
    <input type="submit" value="送信/Submit" />
    <input type="hidden" name="i" value="#{$iframeflag}">
  </form>
  <p class=c>
  <span style="font-weight: bold; color: blue;">青色</span>#{{ja: 'は全死因死亡率、', en: ': All-cause mortality,'}[$l]}
  <span style="font-weight: bold; color: red;">赤色</span>#{{ja: 'は新型コロナ死亡率、', en: ': COVID19 mortality,'}[$l]}
EOF

    if $cgi['r'] == 'true'
        print <<EOF
  <span style="font-weight: bold; color: #ffa500;">橙色</span>#{{ja: 'は呼吸器系疾患死亡率、', en: ': Respiratory mortality,'}[$l]}
EOF
    end

    print <<EOF
  <span style="font-weight: bold; color: #77eeff;">水色</span>#{{ja: 'は2015年〜2019年の全死因死者の最大と最小の範囲', en: ': Min/Max range of 2015-2019 all-cause mortality'}[$l]}<br>
EOF
end

print <<EOF
  <class =l>
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
      "params": [
        {
          "name": "start_year",
          "value": #{start_year},
          "bind": {"input": "range", "min": #{oldest_year}, "max": 2021, "step": 1 }
        }
      ],
      "vconcat": [
EOF

#
# elasticsearch
#
uri = URI.parse("http://localhost:8080/elastic/covid19/_search")
request = Net::HTTP::Get.new(uri)
request.content_type = "application/json"
request.body = <<EOF
{
  "size": 100000,
  "query": {
    "bool": {
      "must": [
        { "range": {"date": {"gte": "#{oldest_year}-01-01", "lt": "now" } } },
        {
          "bool": {
            "should": [
EOF
firstflag = true
$codes.each do | code |
    loc = $locs[code]
    ja = (code =~ /^jp-/) ? :ja : :en
    if firstflag
        firstflag = false
    else
        request.body +=  ",\n"
    end
    request.body += '              { "term": {"location.keyword": "' +
                        $locs[code][ja] + '" } }'
end
request.body += <<EOF
            ]
          }
        }
      ]
    }
  },
  "_source": [
    "date",
    "lift",
    "location",
    "all_cause_deaths_smoothed_per_million",
    "min_all_cause_deaths_smoothed_per_million",
    "max_all_cause_deaths_smoothed_per_million",
    "new_deaths_smoothed",
    "respiratory_deaths_smoothed"
  ]
}
EOF

response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
end

data = JSON.parse(response.body)['hits']['hits']

max = data.max{|a, b| a['_source']['all_cause_deaths_smoothed_per_million'].to_i <=>
                        b['_source']['all_cause_deaths_smoothed_per_million'].to_i}

$dmax = max['_source']['all_cause_deaths_smoothed_per_million'].to_i * 1.05

if $codes.find{|code| code == 'BGR'}
    $dmax = ($dmax < 90) ? $dmax : 90
else
    $dmax = ($dmax < 60) ? $dmax : 60
end

dmax = $cgi['dmax'].to_i
if 20 <= dmax && dmax <= 200
    $dmax = dmax
end

#
# for each country
#
firstflag = true
$codes.each do | code |
    if firstflag
        firstflag = false
    else
        puts ','
    end
    pop0 = $pops["#{code}-2021"]
    [:en, :ja].each do |i|
        if pop0
            break
        end
        pop0 = $pops["#{$locs[code][i]}"]
    end
    if ! pop0
        next
    end

    r = pop0.to_s.length - 3
    r = r < 4 ? 4 : r
    pop = pop0.round(-r)/10000
    max_range = $dmax * pop0 / 1000000
    pop2 = (pop.to_f / 100).round(2)

    ja = (code =~ /^jp-/) ? :ja : :en

    if $l == :ja
        title = "#{$locs[code][$l]}の全死因と新型コロナ死亡率"
        ptitle = "人口#{pop}万人中"
    else
        title = "All-cause and COVID19 mortality in #{$locs[code][$l]}"
        ptitle = "Aginst #{pop2} million pop"
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
                "field": "_source.date",
                "range": [
                  {"year": "#{oldest_year}", "month": "jan", "date": 1},
                  {"year": "#{$to_y}",   "month": "#{$to_m}",   "date": "#{$to_d}"}
                ]
              }
            },
            { "filter": "datum._source.location == \'#{$locs[code][ja]}\'" }
          ],
          "encoding": {
            "x": {
              "title": "#{{ja: '年/月', en: 'Year/Month'}[$l]}",
              "field": "_source.date",
              "type": "temporal",
              "timeUnit": "yearmonthdate",
              "axis": {"format": "%Y/%m"},
              "scale": {
                "domain": [
                  {"year": "start_year", "month": "jan", "date": 1},
                  {"year": "#{$to_y}",   "month": "#{$to_m}",   "date": "#{$to_d}"}
                ]
              }
            }
          },
          "resolve": {"scale": {"y": "independent"}},
          "layer": [
            {
              "mark": {"type": "area", "color": "#77eeff", "clip": true},
              "encoding": {
                "y": {
                  "title": "#{{ja: '日ごと100万人当り', en: 'Daily per million pop'}[$l]}",
                  "field": "_source.max_all_cause_deaths_smoothed_per_million",
                  "type": "quantitative",
                  "aggregate": "max",
                  "scale": {"domain": [0, #{$dmax}]},
                  "axis": {"grid": true}
                },
                "y2": {
                  "field": "_source.min_all_cause_deaths_smoothed_per_million",
                  "type": "quantitative",
                  "aggregate": "min"
                }
              }
            },
            {
              "mark": {"type": "line", "color": "#0000ff", "clip": true},
              "encoding": {
                "y": {
                  "field": "_source.all_cause_deaths_smoothed_per_million",
                  "type": "quantitative",
                  "scale": {"domain": [0, #{$dmax}]},
                  "aggregate": "average",
                  "axis": {"title": "", "labels": false, "ticks": false}
                }
              }
            },
EOF
    if $cgi['r'] == 'true'
        print <<EOF
            {
              "mark": {"type": "line", "color": "#ffa500", "clip": true},
              "encoding": {
                "y": {
                  "field": "_source.respiratory_deaths_smoothed",
                  "type": "quantitative",
                  "aggregate": "average",
                  "scale": {"domain": [0, #{max_range}]},
                  "axis": {"title": "", "labels": false, "ticks": false}
                }
              }
            },
EOF
    end
    print <<EOF
            {
              "mark": {"type": "line", "color": "#ff0000", "clip": true, "strokeDash": [8,3]},
              "encoding": {
                "y": {
                  "title": "#{ptitle}",
                  "field": "_source.new_deaths_smoothed",
                  "type": "quantitative",
                  "aggregate": "average",
                  "scale": {"domain": [0, #{max_range}]},
                  "axis": {"ticks": false}
                }
              }
            }
          ]
EOF
print '        }'
end

print <<EOF
      ],
      "data": {
EOF

print '        "values": '
puts JSON.pretty_generate(data).gsub(/\n/, "\n        ")
print <<EOF
      }
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
      <li> <a href="https://github.com/nytimes/covid-19-data/raw/master/us-states.csv">https://github.com/nytimes/covid-19-data/raw/master/us-states.csv</a>
      <li> <a href="https://www.usmortality.com/">https://www.usmortality.com/</a>
      <li> <a href="https://www3.nhk.or.jp/n-data/opendata/coronavirus/nhk_news_covid19_prefectures_daily_data.csv">https://www3.nhk.or.jp/n-data/opendata/coronavirus/nhk_news_covid19_prefectures_daily_data.csv</a>
      <li> <a href="https://exdeaths-japan.org/data/Observed.csv">https://exdeaths-japan.org/data/Observed.csv</a>
      <li> <a href="https://www.mortality.org/Public/STMF/Inputs/STMFinput.zip">https://www.mortality.org/Public/STMF/Inputs/STMFinput.zip</a>
      <li> <a href="http://data.un.org/Data.aspx?d=POP&f=tableCode%3A65">http://data.un.org/Data.aspx?d=POP&f=tableCode%3A65</a>
      <li> <a href="http://data.un.org/Data.aspx?d=PopDiv&f=variableID%3a12">http://data.un.org/Data.aspx?d=PopDiv&f=variableID%3a12</a>
    </ul>
  </div>
EOF
end

print <<EOF
</body>
</html>
EOF
