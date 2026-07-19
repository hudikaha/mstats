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
else
    $l    = :ja
    $jcheck = 'checked'
end

#
# Height
#
$height = ($cgi['height'] != '' && $cgi['height'].to_i >= 50) ? $cgi['height'].to_i : 200

#
# Width
#
$width = ($cgi['width'] != '') ? $cgi['width'] : '70%'

#
# to Option
#
$to = Date.parse('2023-01-01')
begin
    to = Date.parse($cgi['to'])
    $to = to if to >= Date.parse('2021-01-01')
rescue
end
$to_y = $to.strftime('%Y').to_i
$to_M = $to.strftime('%b')
$to_m = $to.strftime('%m').to_i
$to_d = ($to + 1).strftime('%d').to_i # XXX

#
# from Option
#
$from = Date.parse('2021-01-01')
begin
    from = Date.parse($cgi['from'])
    $from = from if Date.parse('1980-01-01') <= from && from < $to
rescue
end
$from_y = $from.strftime('%Y').to_i
$from_M = $from.strftime('%b')
$from_m = $from.strftime('%m').to_i
$from_d = $from.strftime('%d').to_i

#
# Causes
#
Causes = {
    'all' => {
        en: 'All causes',
        ja: '全死因',
        check: '',
    },
    'ncov19' => {
        en: 'Non-COVID-19 deaths',
        ja: 'コロナ除外死',
        check: '',
    },
    'cov19' => {
        en: 'Deaths involving COVID-19',
        ja: 'コロナ関連死',
        check: '',
    },
}

$atleast = nil
Causes.each do |k, cause|
    if $cgi[k] =~ /1|on|true/
        cause[:check] = 'checked'
        $atleast = true
    end
end

if ! $atleast
    Causes['all'][:check] = 'checked'
    $cause = Causes['all']
end

#
# Ages
#
Ages = {
    'age90' => {
        en: '90+',
        ja: '90+',
        check: '',
    },
    'age80' => {
        en: '80-89',
        ja: '80-89',
        check: '',
    },
    'age70' => {
        en: '70-79',
        ja: '70-79',
        check: '',
    },
    'age60' => {
        en: '60-69',
        ja: '60-69',
        check: '',
    },
    'age50' => {
        en: '50-59',
        ja: '50-59',
        check: '',
    },
    'age40' => {
        en: '40-49',
        ja: '40-49',
        check: '',
    },
    'age18' => {
        en: '18-39',
        ja: '18-39',
        check: '',
    },
}

$atleast = nil
Ages.each do |k, age|
    if $cgi[k] =~ /1|on|true/
        age[:check] = 'checked'
        $atleast = true
    end
end

if ! $atleast
    Ages.each do |k, age|
        age[:check] = 'checked'
    end
end

#
# States
#
States = {
    'Unvaccinated' =>
    {
        en: '0 Unvaccinated',
        ja: '0 未接種',
        cgi: 'uvaxx',
        check: ''
    },
    'First dose, less than 21 days ago' => {
        en: '1st dose <21 days ago',
        ja: '1回接種(20日以内)',
        cgi: '1st20',
        check: ''
    },
    'First dose, at least 21 days ago' => {
        en: '1st dose >=21 days ago',
        ja: '1回接種(21日以上)',
        cgi: '1st21',
        check: ''
    },
    'Second dose, less than 21 days ago' => {
        en: '2nd dose <21 days ago',
        ja: '2回接種(20日以内)',
        cgi: '2nd20',
        check: ''
    },
    'Second dose, at least 21 days ago' => {
        en: '2nd dose >=21 days ago',
        ja: '2回接種(21日以上)',
        cgi: '2nd21',
        check: ''
    },
    'Third dose or booster, less than 21 days ago' => {
        en: '3rd dose or booster <21 days ago',
        ja: '3回接種(20日以内)',
        cgi: '3rd20',
        check: ''
    },
    'Third dose or booster, at least 21 days ago' => {
        en: '3rd dose or booster >=21 days ago',
        ja: '3回接種(21日以上)',
        cgi: '3rd21',
        check: ''
    },
    'Vaccinated (calculated at this site)' => {
        en: 'Vaccinated (calculated at this site)',
        ja: '接種歴あり(本サイトで計算)',
        cgi: 'vaxx',
        check: '',
    },
}

$atleast = false
States.each do |k, state|
    if $cgi[state[:cgi]] =~ /1|on|true/
        state[:check] = 'checked'
        $atleast = true
    end
end

if ! $atleast
    ['Unvaccinated',
     'Second dose, at least 21 days ago',
     'Third dose or booster, less than 21 days ago',
     'Third dose or booster, at least 21 days ago'].each do |key|
        States[key][:check] = 'checked'
    end
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

print_header(:title => ($l == :ja ?
                            "イングランドのワクチン接種状況別死亡率" :
                            "Mortality in England by Vaccination Status"),
             :iframe => $iframeflag)

if ! $iframeflag
    print <<EOF
  <p class=l>
  <form action="enmort.rb" method="get" style="text-align: center;">
EOF
    Causes.each do |k, cause|
        print <<EOF
    <span><input type="checkbox" name="#{k}" value="true" #{cause[:check]}>#{cause[$l]}</span>
EOF
    end
    print <<EOF
    <br>
    #{{en: 'Age', ja: '年齢区分'}[$l]}
EOF
    Ages.each do |k, age|
        print <<EOF
    <span><input type="checkbox" name="#{k}" value="true" #{age[:check]}>#{age[$l]}</span>
EOF
    end
    print <<EOF
    <br>
EOF
    States.each do |k, state|
        print <<EOF
    <span><input type="checkbox" name="#{state[:cgi]}" value="true" #{state[:check]}>#{state[$l]}</span>
EOF
    end
    print <<EOF
    <br>
    #{{ja:'開始日',en:'From'}[$l]} <input type="text" name="from" value="#{$from}" size="10"/>
    #{{ja:'終了日',en:'To'}[$l]} <input type="text" name="to" value="#{$to}" size="10"/>
    <input type="radio" name="l" value="ja" #{$jcheck}>日本語
    <input type="radio" name="l" value="en" #{$echeck}>English
    <input type="submit" value="送信/submit" />
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
        "legend": {"titleFontSize": 14, "labelFontSize": 14, "labelLimit": 0}
      },
      "data": {
EOF
    print '        "values": '

data0 = elastic2(
    :index => 'en-mortality',
    :must => [],
    :should => [],
    :source => [],
    #:debug => 'SHOWONLY',
)

$data = Array.new

data0.each do |datum|
    #next if States[datum['_source']['Vaccination status']][:check] != 'checked'
    #if ! (found = States.find{|k, v| datum['_source']['Vaccination status'] == v[:en]})
    #    STDERR.put("Error\n")
    #    exit 1
    #end
    datum2 = { 'date' =>
               Date.parse("#{datum['_source']['Month']} 1 #{datum['_source']['Year']}")}
    datum['_source'].each do |k, v|
        if k == 'Cause of Death' ||
           k == 'Age group' ||
           k == 'Vaccination status'
            datum2[k] = v
        elsif k == "Age-standardised mortality rate / 100,000 person-years" ||
           k == 'Count of deaths' ||
           k == 'Person-years'
            datum2[k] = v.to_i
            datum2[k] = nil if ! datum2[k].kind_of?(Numeric) || datum2[k] < 1
        end
    end
    $data.push(datum2)
end

enddate = Date.parse("#{$to_y}-#{$to_M}-1")
if States['Vaccinated (calculated at this site)'][:check] == 'checked'
    Causes.each do |k, cause|
        date = Date.parse("#{$from_y}-#{$from_M}-1")
        while date <= enddate
            Ages.each do |k, age|
                data = $data.select{|datum| datum['Cause of Death'] == cause[:en] &&
                                    datum['date'] == date &&
                                    datum['Age group'] == age[:en] &&
                                    datum['Vaccination status'] != 'Unvaccinated'}
                next if data == []
                deaths = data.sum{|datum| datum['Count of deaths'].kind_of?(Numeric) ?
                                           datum['Count of deaths'] : 0}
                pops   = data.sum{|datum| datum['Person-years'].kind_of?(Numeric) ?
                                           datum['Person-years'] : 0}
                if pops > 0
                    mortality = (deaths.to_f * 100000 / pops.to_f).round(1)
                else
                    mortality = ''
                end

                $data.push({
                    'Cause of Death' => cause[:en],
                    'Age group' => age[:en],
                    'Vaccination status' => 'Vaccinated (calculated at this site)',
                    'Count of deaths' => deaths,
                    'Person-years' => pops,
                    'Age-standardised mortality rate / 100,000 person-years' => mortality,
                    'date' => date,
                })

            end
            date >>= 1
        end
    end
end

data = Array.new

$data.each do |datum|
    next if States[datum['Vaccination status']][:check] != 'checked'
    datum['Vaccination status'] = States[datum['Vaccination status']][$l]
    data.push(datum)
end

puts JSON.pretty_generate(data).gsub(/\n/, "\n        ")

print <<EOF
      },
      "vconcat": [
EOF
firstflag = true
Ages.each do |k0, age0|
    next if age0[:check] != 'checked'
    age = age0[:en]
    max0 = data.select{|v| v['Age group'] == age}.
               max{|a, b| a["Age-standardised mortality rate / 100,000 person-years"].to_i <=>
                          b["Age-standardised mortality rate / 100,000 person-years"].to_i}
    max = max0["Age-standardised mortality rate / 100,000 person-years"].to_f * 1.1
    Causes.each do |k, cause|
        next if cause[:check] != 'checked'
        if firstflag
            firstflag = false
        else
            print <<EOF
        ,
EOF
        end
        title = {en: "Age #{age} #{cause[:en]} mortality rate / 100,000 person-years",
                 ja: "#{age}歳の#{cause[:ja]} 月ごとの10万人当り年間死亡数"}[$l].
                    sub('90+歳', '90歳以上')
        print <<EOF
        {
          "width": "container",
          "height": #{$height},
          "encoding": {
            "x": {
              "title": "#{{en: 'Year/Month', ja: '年/月'}[$l]}",
              "field": "date",
              "type": "temporal",
              "axis": {"format": "%Y/%m"},
            }
          },
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
            { "filter": "datum['Age group'] == '#{age}'"},
            { "filter": "datum['Cause of Death'] == '#{cause[:en]}'"},
          ],
          "layer": [
            {
              "title": "#{title}",
              "mark": { "type": "line", "point": true },
              "params": [
                {
                  "name": "state",
                  "select": {"type": "point", "fields": ["Vaccination status"]},
                  "bind": {"legend": "mouseover"}
                }
              ],
              "encoding": {
                "y": {
                  "title": null,
                  "field": "Age-standardised mortality rate / 100,000 person-years",
                  "type": "quantitative",
                  "scale": {"domain": [0, #{max}]}
                },
                "color": {
                  "title": "#{{en: 'Vaccination status', ja: '接種状況'}[$l]}",
                  "field": "Vaccination status",
                  "scale": {"scheme": "magma"},
                  "type": "nominal"
                },
                "opacity": {"condition": {"param": "state", "value": 1}, "value": 0.1}
              }
            },
            {
              "transform": [
                {
                  "pivot": "Vaccination status",
                  "value": "Age-standardised mortality rate / 100,000 person-years",
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
        States.each do |k2, state|
            next if state[:check] != 'checked'
            print <<EOF
                  {"field": "#{state[$l]}", "type": "quantitative"},
EOF
        end
        print <<EOF
                  {
                    "title": "#{{ja: '年/月', en: 'Year/Month'}[$l]}",
                    "timeUnit": "yearmonth",
                    "field": "date",
                    "format": "%Y/%m"
                  }
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
        }
EOF
    end
end
print <<EOF
      ],
      "resolve": { "scale": { "color": "independent" } }
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
   <li> <a href="https://www.ons.gov.uk/peoplepopulationandcommunity/birthsdeathsandmarriages/deaths/datasets/deathsbyvaccinationstatusengland">Deaths by vaccination status, England</a>
  </ul>
EOF
end
print <<EOF
</body>
</html>
EOF

#
