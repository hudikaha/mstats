#!/usr/bin/ruby
# coding: utf-8
# ruby-indent-level: 4
#

require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require 'date'
require 'optparse'
require 'pp'

mfacts = [
    File.expand_path('../lib/mfacts.rb', __dir__),
    File.expand_path('lib/mfacts.rb', __dir__)
].find { |path| File.file?(path) }
abort 'lib/mfacts.rb not found' unless mfacts
require mfacts

mstats = [
    File.expand_path('../vdeath/lib/mstats.rb', __dir__),
    File.expand_path('mstats.rb', __dir__)
].find { |path| File.file?(path) }
abort 'mstats.rb not found' unless mstats
require mstats
require './mort-vars.rb'

#
# Debug opttion
#
$opts = {
    debug: false,
    index: "mstats"
}

op = OptionParser.new do |opts|
    opts.on('--debug yes|no', String, 'Debug on') do |value|
        if value =~ /true|yes|on/
            $opts[:debug] = true
            Log.level = Logger::DEBUG
        end
    end
    opts.on('--index <index>', String, 'Index for ElasticSearch') do |value|
        $opts[:index] = value
    end
end
begin
    op.parse!
rescue
    puts op
    exit
end

# 数値を3桁区切りで表示する。 / Format a number with thousands separators.
def add_commas(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

#
# CGI.new
#
$cgi = CGI.new

Consts = {
    'l'     => { hash: Lang,   defaults: ['en'],         selected: 'checked' },
    'i'     => { hash: IFrame, defaults: ['false'],      selected: 'checked' },
    'vaxx'  => { hash: Vaxx,   defaults: ['false'],      selected: 'checked' },
    'cmpys' => { hash: Cmpys,  defaults: ['5'],          selected: 'selected'},
    'cmpto' => { hash: Cmpto,  defaults: ['2019'],       selected: 'selected'},
    'types' => { hash: Types,  defaults: ['death_amr'],  selected: 'checked', keys: [] },
    'ages'  => { hash: Ages,   defaults: ['age_all'],    selected: 'checked', keys: [] },
    'sexes' => { hash: Sexes,  defaults: ['both'],       selected: 'checked', keys: [] },
    'c'     => { hash: Locs,   defaults: ['JPN','SWE','ENG'], selected: 'checked', keys: [] },
    'death_codes' => { hash: Death_codes, defaults: ['00000'], selected: 'selected',keys: []},
}

Consts.each do |k, v|

    # 選択されたものだけチェック
    keys = $cgi[k].split(/,|~|、/)
    keys.each do |key|
        v[:hash][key][:sel] = v[:selected] if v[:hash][key]
    end

    # $locs, $ages, $sexes を設定、これは CGI と同じにする
    if v[:keys]
        v[:keys] += keys
    end

    # $l を設定
    if k == 'l'
        if ! Lang['en'][:sel] && ENV['HTTP_ACCEPT_LANGUAGE'] =~ /^ja/
            Lang['ja'][:sel] = Consts['l'][:selected]
        end
    end

    # 選択されたものが無ければ default 設定
    if ! v[:hash].find{|k2, v2| v2[:sel] != nil}
        v[:defaults].each do |key|
            v[:hash][key][:sel] = v[:selected]
        end
    end

    # CGI と Consts が同じなら、CGI の並びは活かす。でなければ Consts の並び
    if v[:keys]
        keys2 = v[:hash].select{|k, v| v[:sel]}.keys
        v[:keys] = keys2 if v[:keys].sort != keys2.sort
    end
end

$l     = Lang.find{|k, v| v[:sel]}[0].to_sym
$cmpys = Cmpys.find{|k, v| v[:sel]}[0].to_i
$cmpto = Cmpto.find{|k, v| v[:sel]}[0].sub(/^reg|^every|^ereg/,'').to_i
$types = Consts['types'][:keys]
$ages  = Consts['ages'][:keys]
$sexes = Consts['sexes'][:keys]
$locs  = Consts['c'][:keys]
$death_codes = Consts['death_codes'][:keys]

#Log.debug PP.pp(Cmpto, '')
#Log.debug PP.pp($cmpto, '')
#exit

$rates = []
$algos = []
$types.each do |type|
    $rates += Types[type][:rate]
    $algos += Types[type][:algo]
end
$rates.uniq!
$algos.uniq!

$start_year = ($cmpto - $cmpys + 1) < 2015 ? 2015 : ($cmpto - $cmpys + 1)
$start_year = 2015 if Cmpto['every2020'][:sel]
$start_year =  $cgi['start'].to_i if $cgi['start'] &&
                                     2009 <= $cgi['start'].to_i && $cgi['start'].to_i <= 2019

Log.debug PP.pp(Vaxx, '')

#pp $types, $rates, $algos
#exit

#
# Height
#
$height = ($cgi['height'] != '' && $cgi['height'].to_i >= 50) ? $cgi['height'].to_i : 150

#
# Width
#
$width = ($cgi['width'] != '') ? $cgi['width'] : '90%'

#
# to Option
#
$to = Date.today
begin
    to = Date.parse($cgi['to'])
    $to = to if to >= Date.parse('1980-01-01')
rescue
end
$to_y = $to.strftime('%Y').to_i
$to_M = $to.strftime('%b')
$to_m = $to.strftime('%m').to_i
$to_d = $to.strftime('%d').to_i

print_header(:title => Lang[$l.to_s][:title], :iframe => IFrame['true'][:sel])

if Cmpto['every2019'][:sel] || Cmpto['every2020'][:sel]
    $range_str = {ja: "過去5年間", en: "Past 5 years"}[$l]
else
    $range_str = ($cmpys == 1) ? $cmpto.to_s : "#{$cmpto-$cmpys+1}-#{$cmpto}"
    $range_str += '年' if $l == :ja
end

if IFrame['false'][:sel]
    print <<EOS
  <p class=l>
  <script>
  function submitForm() {
    var l = document.querySelector('input[name="l"]:checked').value;
    var cmpys = Array.from(document.querySelectorAll('select[name="cmpys"] option:checked'),
                           option => option.value);
    var cmpto = Array.from(document.querySelectorAll('select[name="cmpto"] option:checked'),
                           option => option.value);
    var types = Array.from(document.querySelectorAll('input[name="types"]:checked'),
                           checkbox => checkbox.value);
    var ages =  Array.from(document.querySelectorAll('input[name="age"]:checked'),
                           checkbox => checkbox.value);
    var sexes = Array.from(document.querySelectorAll('input[name="sexes"]:checked'),
                           checkbox => checkbox.value);
    var death_codes = Array.from(document.querySelectorAll('select[name="death_codes"] option:checked'),
                           option => option.value);
    var c =     Array.from(document.querySelectorAll('input[name="c"]:checked'),
                           checkbox => checkbox.value);

    var queryString = 'mort.rb?l=' + l
        + '&cmpys=' + cmpys
        + '&cmpto=' + cmpto
        + '&types=' + types.join('~')
        + '&ages=' + ages.join('~')
        + '&sexes=' + sexes.join('~')
        + '&death_codes=' + death_codes
        + '&c=' + c.join('~')
    ;
    window.location.href = queryString;
  }
  </script>
  <form id="myForm" onsubmit="submitForm(); return false;" style="text-align: left;">
EOS
    Types.each do |k, v|
        next if k =~ /^death__excess$/
        print <<EOS
    <span><input type="checkbox" name="types" value="#{k}" #{v[:sel]}> #{v[$l]}</span>
EOS
    end
    print <<EOS
    <span>
      #{{ja:'', en:'in Comp with'}[$l]}
      <select name="cmpto">
EOS
    Cmpto.each do |k, v|
        print <<EOS
        <option value="#{k}" #{v[:sel]}>#{v[$l]}</option>
EOS
    end
    print <<EOS
      </select>
      <select name="cmpys">
EOS
    Cmpys.each do |k, v|
        print <<EOS
        <option value="#{k}" #{v[:sel]}>#{v[$l]}</option>
EOS
    end
    print <<EOS
      </select>
      #{{ja:'と比較', en:''}[$l]}
    </span>
    <br>
EOS
    Ages.each do |k, v|
        next if v[:jp_spec]
        print <<EOS
    <span><input type="checkbox" name="age" value="#{k}" #{v[:sel]}> #{v[$l]}</span>
EOS
    end
    print <<EOS
    <span>
EOS
    Sexes.each do |k, v|
        print <<EOS
      <input type="checkbox" name="sexes" value="#{k}" #{v[:sel]}> #{v[$l]}
EOS
    end
    print <<EOS
    </span>
    <br>
EOS
    print <<EOS
    <span>
      (#{{ja: "日本独自オプション: ", en: "Japan-specific options: "}[$l]}
EOS
    print <<EOS
      <select name="death_codes">
EOS
    Death_codes.each do |k, v|
        print <<EOS
        #{k}
        <option value="#{k}" #{v[:sel]}>#{k}: #{v[$l]}</option>
EOS
    end
    print <<EOS
      </select>
EOS
    Ages.each do |k, v|
        next if ! v[:jp_spec]
        print <<EOS
      <input type="checkbox" name="age" value="#{k}" #{v[:sel]}> #{v[$l]}
EOS
    end
    print <<EOS
    )
    </span>
    <br>
EOS
    Locs.each do |k, v|
        print <<EOS
    <span><input type="checkbox" name="c" value="#{k}" #{v[:sel]}> #{v[$l]}</span>
EOS
    end
    print <<EOS
    <br>
    <span>
EOS
    Lang.each do |k, v|
        print <<EOS
      <input type="radio" name="l" value="#{k}" #{v[:sel]}> #{v[$l]}</span>
EOS
    end
    print <<EOS
      <input type="submit" value="送信/Submit">
    </span>
  </form>
  <h3 style="text-align: center;">#{{ja: '下のスライドバーで遡って表示', en:'Display earlier years using the slider below'}[$l]}</h3>
EOS
end
print <<EOS
  <p class=c>
  <span style="color: blue; text-weight: bold;">━━</span>
  #{{ja: '死者数・死亡率 &nbsp;', en: 'Deaths/Mortality &nbsp;'}[$l]}
EOS

Avgcolor = "darkturquoise"
Mincolor = "cyan"
Regcolor = "salmon"

$hasen = '━ ━'

if Cmpto['reg2018'][:sel] || Cmpto['reg2019'][:sel] || Cmpto['reg2020'][:sel]
    $regflag = true
else
    $regflag = false
end

if $regflag
            print <<EOS
  <span style="color: #{Avgcolor};">#{$hasen}</span>
  #{{ja: $range_str+'から週ごと計算の回帰線 &nbsp;',
     en: 'SLR calculated for every week from '+$range_str+' &nbsp;'}[$l]}
  <span style="color: #{Regcolor}; text-weight: bold;">#{$hasen}</span>
  #{{ja: '予測線', en: 'Estimated line'}[$l]}
EOS
elsif Cmpto['ereg2019'][:sel] || Cmpto['ereg2020'][:sel]
    yosoku_str = {ja: "直近#{$cmpys}年間からの予測線",
                  en: "Estimated line from prev #{$cmpys} years"}[$l]
            print <<EOS
  <span style="color: #{Avgcolor};">#{$hasen}</span>
  #{{ja: $range_str+'から週ごと計算の回帰線 &nbsp;',
     en: 'SLR calculated for every week from '+$range_str+' &nbsp;'}[$l]}
  <span style="color: #{Regcolor}; text-weight: bold;">#{$hasen}</span>
  #{yosoku_str}
EOS
else
    if $types.include?('death') || $types.include?('death_amr')
        if $cmpys > 1
            print <<EOS
  <span style="color: #{Mincolor};">██</span>
  #{{ja: $range_str+'の最大と最小の範囲 &nbsp;',
     en: 'Min/Max Range of '+$range_str+' &nbsp;'}[$l]}
  <span style="color: #{Avgcolor}; text-weight: bold;">#{$hasen}</span>
  #{{ja: $range_str+'の平均', en: 'Avg of '+$range_str}[$l]}
EOS
        else
            print <<EOS
  <span style="color: #{Avgcolor}; text-weight: bold;">#{$hasen}</span>
  #{{ja: $range_str+'の値', en: 'Values of '+$range_str}[$l]}
EOS
        end
    end
end

print <<EOS
  <h3 style="text-align: center;">#{$title} #{$append}</h3>
  <p class=c>
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
EOS
print '        "values": '

$must_not = ['exists' => {'field' => 'death_code'}]
$must = [
    {'terms' => {'category.keyword' => ['death']}},
    {'terms' => {'rate.keyword' => $rates}},
    {'terms' => {'algo.keyword' => ['']}},
    {'terms' => {'loc_code.keyword' => $locs}},
    {'terms' => {'sex.keyword' => $sexes}}
]
if $death_codes[0] != '00000'
    $must_not = []
    $must += [ {'term' => {'death_code.keyword' => $death_codes[0]}} ]
end

$should = []
$locs.each do |loc_code|
    ['death'].each do |category|
        $rates.each do |rate|
            $sexes.each do |sex|
                $death_codes.each do |death_code|
                    if loc_code == 'JPN' #&&
                       #($ages.include?('age_00_04') ||
                       # $ages.include?('age_05_14') ||
                       # $ages.include?('age_15_29'))
                        $should.push('regexp' => {'doc_id.keyword' => "#{loc_code}_.*_#{category}_#{rate}_#{death_code}_.*_#{sex}"})
                        $should.push('regexp' => {'doc_id.keyword' => "#{loc_code}_.*_c19vaxx____#{sex}"})
                    elsif death_code == '00000'
                        $should.push('regexp' => {'doc_id.keyword' => "#{loc_code}_.*_#{category}_#{rate}___#{sex}"})
                    end
                end
            end
        end
    end
end

Log.debug $should

data0 = elastic3(
    :index => $opts[:index],
    #:must_not => $must_not,
    #:must => $must,
    #:should => [],
    :must_not => [],
    :must => [], # specify range in the future
    :should => $should,
    :source => [ 'doc_id', 'loc_code', 'yearweek', 'category', 'rate', 'death_code',
                 'algo', 'date', 'year', 'week', 'sex', 'age_all' ] + $ages,
    #:debug => 'SHOWONLY_QUERY',
)

data = data0.select{|k, datum| datum[:category] == 'death'}

Log.debug PP.pp(data, '')

$loc_codes = data.map{|k, datum| datum[:loc_code]}.sort.uniq
$sexes = data.map{|k, datum| datum[:sex]}.sort.uniq
$rates = data.map{|k, datum| datum[:rate]}.sort.uniq

$min    = "min#{$cmpys}to#{$cmpto}"
$max    = "max#{$cmpys}to#{$cmpto}"
$avg    = "avg#{$cmpys}to#{$cmpto}"
$diff   = "diff#{$cmpys}to#{$cmpto}"
$excess = "excess#{$cmpys}to#{$cmpto}"

#
# Calculate excess mortality
#
$morts = []
$loc_codes.each do |loc_code|
    morts_loc = Mstats[data].select{|k, mort| mort[:loc_code] == loc_code}
    next if ! morts_loc
    $rates.each do |rate|
        morts_loc_rate = morts_loc.select{|k, mort| mort[:rate] == rate}
        next if ! morts_loc_rate
        $sexes.each do |sex|
            morts_loc_rate_sex = morts_loc_rate.select{|k, mort| mort[:sex] == sex}
            next if ! morts_loc_rate_sex
            morts2 = Mstats.new
            if Cmpto['every2019'][:sel] || Cmpto['every2020'][:sel]
                Log.debug "Every #{$cmpys}..."
                (2014..$to_y-2).each do |to_year|
                    Log.debug "#{$cmpys}, #{to_year}"
                    morts2.merge!(morts_loc_rate_sex.excess(years: $cmpys, to: to_year,
                                                            apply: to_year+1,
                                                            suffix: "#{$cmpys}to#{$cmpto}"))
                end
                Log.debug PP.pp(morts2, '')
                #exit
            elsif $regflag
                Log.debug "Regression..."
                morts2 = morts_loc_rate_sex.regression(years: $cmpys, to: $cmpto)
            elsif Cmpto['ereg2019'][:sel] || Cmpto['ereg2020'][:sel]
                Log.debug "Every Regression.."
                morts2 = morts_loc_rate_sex.everyreg(years: $cmpys, to: $cmpto)
                $regflag = true
            elsif $cmpto == 2019 || $cmpto == 2020
                morts2 = morts_loc_rate_sex.excess(years: $cmpys, to: $cmpto)
            end
            $morts.push(morts2)
            $morts.push(morts2.select{|k, v| v[:year] > $cmpto}.cumuldiff)
        end
    end
end

$morts.each do |morts|
    data.merge!(morts)
end

# Add min, max, avg
$data = Hash.new
$oldest_year = $start_year
data.each do |id0, datum|
    $oldest_year = (datum[:year] >= 1980 && datum[:year] < $oldest_year) ?
                       datum[:year] : $oldest_year

    if datum[:algo] == $min || datum[:algo] == $max || datum[:algo] == $avg
        id = id0.sub(/#{$min}|#{$max}|#{$avg}/, '')
        next if ! data[id]
        #if ! data[id]
        #    Log.debug "#{id} was not found #{id0}"
        #    exit
        #    next
        #end
        datum.each do |k, v|
            if k =~ /^age/
                Log.debug "#{id} #{id0} #{datum[:algo]}"
                data[id]["#{k}_#{datum[:algo]}".to_sym] = v
            end
        end
    else
        $data[id0] = datum #if datum[:week] == 1 && (2019 <= datum[:year] && datum[:year] <= 2022)
    end
end

$c19vaxxes = data0.select{|k, datum| datum[:category] == 'c19vaxx'}
if $c19vaxxes
    merged = $data.merge($c19vaxxes)
    puts JSON.pretty_generate(merged.values.sort{|a,b|a['date']<=>b['date']}).gsub(/\n/, "\n        ")
else
    puts JSON.pretty_generate($data.values.sort{|a,b|a['date']<=>b['date']}).gsub(/\n/, "\n        ")
end

print <<EOS
      },
EOS
if IFrame['false'][:sel]
    print <<EOS
      "params": [
        {
          "name": "Start_year",
          "value": #{$start_year},
          "bind": {"input": "range", "min": #{$oldest_year}, "max": 2019, "step": 1 }
        },
        {
          "name": "Vaxx",
          "value": #{Vaxx['true'][:sel] ? 'true' : 'false'},
          "bind": {"input": "checkbox"}
        }
      ],
EOS
    $start_year2 = '"Start_year"'
else
    $start_year2 = $start_year
end
print <<EOS
      "vconcat": [
EOS

BAI = 1.05

firstflag = true
$types.each do |type|
    rate = Types[type][:rate][0]
    algo = Types[type][:algo][0]
    algo += "#{$cmpys}to#{$cmpto}" if algo != '' && algo != 'cumuldiff'

    yformat = ',.0d'
    if rate == 'amr'
        yformat = ',.2f'
    end
    if algo =~ /excess/
        yformat = '.0%'
    end

    Log.debug("#{type} #{rate} #{algo}")

    $ages.each do |age|
        $sexes.each do |sex|

            # Arrange MIN, MAX for all the country when AMR
            min = nil
            max = nil
            scale = ''
            if rate == 'amr' #&& $locs.count > 1
                data_sex = $data.select{|k, v| v[:sex] == sex}

                if algo == ''
                    data2 = data_sex.select{|k, v| v[:rate] == 'amr' && v[:algo] == ''}.
                                map{|k, v| v[age.to_sym]}.compact
                    (min, max) = (data2 != []) ? data2.minmax : [nil, nil]
                    #max = max < 100000 ? max : 100000
                    scale = '"scale": { "domain": [0, ' +
                            (max * BAI).round(2).to_s + '] },' if max
                else
                    data2 = data_sex.select{|k, v| v[:rate] == 'amr' &&
                                            v[:algo] =~ /^#{algo}/}.
                                map{|k, v| v[age.to_sym]}.compact
                    (min, max) = (data2 != []) ? data2.minmax : [nil, nil]
                    if algo =~ /^diff/ && min && max
                        #min = min > -300 ? min : -300
                        #max = max < 300 ? max : 300
                        scale = '"scale": { "domain": [' +
                                (min * BAI).round(2).to_s + ', ' +
                                (max * BAI).round(2).to_s + '] },'
                    elsif algo =~ /^excess/ && min && max
                        #min = min > -0.10 ? min : -0.10
                        #max = max < 0.30 ? max : 0.30
                        scale = '"scale": { "domain": [' +
                                (min * BAI).round(2).to_s + ', ' +
                                (max * BAI).round(2).to_s + '] },'
                    elsif algo =~ /^cumuldiff/ && min && max
                        #min = min > -100 ? min : -100
                        #max = max < 300 ? max : 300
                        scale = '"scale": { "domain": [' +
                                (min * BAI).round(2).to_s + ', ' +
                                (max * BAI).round(2).to_s + '] },'
                    end
                end

                Log.debug "#{type} #{min} #{max} #{scale}"
            end

            $locs.each do |loc|
                # Title
                if $l == :ja
                    title = "#{Locs[loc][$l]}における#{Ages[age][$l]}の" +
                            "#{Types[type][$l]}"
                else
                    title0 = "#{Types[type][$l]}"
                    title2 = " of #{Ages[age][$l]} in #{Locs[loc][$l]}"
                    if title0 =~ /(^.*)(\(.*\))/
                        title = title0.sub(/(^.*)( \(.*\))/, '\1' + title2 + '\2')
                    else
                        title = title0 + title2
                    end
                end

                # Title (Sex)
                if sex != 'both'
                    if title =~ /\).*$/
                        title.sub!(/\).*$/, ", #{Sexes[sex][$l]})")
                    else
                        title += " (#{Sexes[sex][$l]})"
                    end
                end

                # Title (Death cause)
                if $death_codes[0] != nil && Death_codes[$death_codes[0]]
                    if title =~ /\).*$/
                        title.sub!(/\).*$/, ", #{Death_codes[$death_codes[0]][$l]})")
                    else
                        title += " (#{Death_codes[$death_codes[0]][$l]})"
                    end
                end

                # Title (Cumuldiff)
                if type == 'death_amr_cumuldiff'
                    data_cumuldiff = $data.select{|k, v| v[:loc_code] == loc &&
                                                  v[:sex] == sex &&
                                                  v[:algo] == 'cumuldiff'}
                    if data_cumuldiff != {}
                        datum = data_cumuldiff.to_a[-1][1]
                        cumuldiff = datum[age.to_sym]
                        title2 = {ja: ", 計 #{cumuldiff}/10万人)",
                                  en: ", Total #{cumuldiff}/100k pops)"}[$l]
                        title = title.sub(/\).*$/, '') + title2

                        pop = Pops["#{loc}_#{datum[:year]}"]
                        if pop &&
                           age == 'age_all' && sex == 'both' #&& $death_codes[0] == '00000'
                            total = ((cumuldiff * pop / 100000)/1000).round * 1000
                            total_str = add_commas(total)
                            if $l == :ja
                                if total >= 10000
                                    if total%10000 > 0
                                        total_str = "#{total/10000}万#{total%10000}"
                                    else
                                        total_str = "#{total/10000}万"
                                    end
                                end
                            end
                            title2 = {ja: ", 実数推計 #{total_str}人)",
                                      en: ", estimated actual #{total_str})"}[$l]
                            title = title.sub(/\).*$/, '') + title2
                        end
                    end
                end

                if ! firstflag
                    puts '        ,'
                else
                    firstflag = false
                end
                print <<EOS
        {
          "title": {
            "text": "#{title}",
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "encoding": {
            "x": {
              "title": "#{{ja: '年-月', en: 'Year-Month'}[$l]}",
              "field": "date",
              "type": "temporal",
              "timeUnit": "yearmonthdate",
              "axis": {"format": "%Y-%m"},
              "scale": {
                "domain": [
                  {"year": #{$start_year2}, "month": "Jan", "date": 1},
                  {"year": #{$to_y}, "month": "#{$to_M}", "date": #{$to_d}}
                ]
              }
            }
          },
          "layer": [
EOS
                trans = <<EOS
              "transform": [
                { "filter": "datum.category == 'death'" },
                { "filter": "datum.loc_code == '#{loc}'" },
                { "filter": "datum.rate == '#{rate}'" },
                { "filter": "datum.algo == '#{algo}'" },
                { "filter": "datum.sex  == '#{sex}'" }
              ],
EOS
                if type =~ /^death$|^death_amr$/
                    stroke = '"strokeDash": [5,3], "strokeWidth": 5'
                    regtrans = ''
                    if $regflag
                        regtrans = <<EOS
              "transform": [
                { "filter": "datum.category == 'death'" },
                { "filter": "datum.loc_code == '#{loc}'" },
                { "filter": "datum.rate == '#{rate}'" },
                { "filter": "datum.algo == '#{algo}'" },
                { "filter": "datum.sex  == '#{sex}'" },
                { "filter": "datum.year <= #{$cmpto}" },
              ],
EOS
                    else
                        regtrans = <<EOS
              "transform": [
                { "filter": "datum.category == 'death'" },
                { "filter": "datum.loc_code == '#{loc}'" },
                { "filter": "datum.rate == '#{rate}'" },
                { "filter": "datum.algo == '#{algo}'" },
                { "filter": "datum.sex  == '#{sex}'" }
              ],
EOS
                    end
                    print <<EOS
            {
#{trans}
              "mark": {"type": "area", "clip": true, "color": "#{Mincolor}"},
              "encoding": {
                "y": {
                  "field": "#{age}_#{$max}",
                  "type": "quantitative",
                  "aggregate": "average",
                  #{scale}
                  "axis": {"title": ""}
                },
                "y2": {
                  "field": "#{age}_#{$min}",
                  "type": "quantitative",
                  "aggregate": "average",
                  "axis": {"title": ""}
                }
              }
            },
            {
#{regtrans}
              "mark": {"type": "line", "clip": true, "color": "#{Avgcolor}", #{stroke}},
              "encoding": {
                "y": {
                  "field": "#{age}_#{$avg}",
                  "type": "quantitative",
                  "aggregate": "average",
                  #{scale}
                  "axis": {"title": ""}
                }
              }
            },
EOS
                    if $regflag
                        print <<EOS
            {
              "transform": [
                { "filter": "datum.category == 'death'" },
                { "filter": "datum.loc_code == '#{loc}'" },
                { "filter": "datum.rate == '#{rate}'" },
                { "filter": "datum.algo == '#{algo}'" },
                { "filter": "datum.sex  == '#{sex}'" },
                { "filter": "datum.year > #{$cmpto}" },
              ],
              "mark": {"type": "line", "clip": true, "color": "#{Regcolor}", #{stroke}},
              "encoding": {
                "y": {
                  "field": "#{age}_#{$avg}",
                  "type": "quantitative",
                  "aggregate": "average",
                  #{scale}
                  "axis": {"title": ""}
                }
              }
            },
EOS
                    end
                    print <<EOS
            {
#{trans}
              "mark": {"type": "line", "clip": true, "color": "mediumblue", "strokeWidth": 3},
              "encoding": {
                "y": {
                  "field": "#{age}",
                  "type": "quantitative",
                  "aggregate": "average",
                  #{scale}
                  "axis": {"title": "", "format": "#{yformat}",
                           "orient": "right", "grid": true }
                }
              }
            }
EOS
                else
                    print <<EOS
            {
#{trans}
              "mark": {"type": "area", "clip": true, "color": "mediumblue"},
              "encoding": {
                "y": {
                  "field": "#{age}",
                  "type": "quantitative",
                  "aggregate": "average",
                  #{scale}
                  "axis": {"title": "", "format": "#{yformat}",
                           "orient": "right", "grid": true  }
                }
              }
            }
EOS
                end
                if (IFrame['true'][:sel] && Vaxx['true'][:sel] ||
                    IFrame['false'][:sel]) &&
                   loc == 'JPN' && type =~ /_diff$|_excess$/ && max && max > 0
                    print <<EOS
            ,
            {
              "transform": [
                { "filter": "datum.category == 'c19vaxx'" },
                { "filter": "datum.loc_code == 'JPN'" },
                { "filter": "datum.sex  == '#{sex}'" },
                { "calculate": "#{min}+datum.age_all*(#{max} - #{min})/12000000","as":"vaxx" }
              ],
              "mark": {"type": "line", "clip": true, "color": "crimson", "strokeWidth": 3},
              "encoding": {
                "y": {
                  "field": "vaxx",
                  "type": "quantitative",
                  "aggregate": "average",
                  #{scale}
                  "axis": {"title": "", "format": "#{yformat}",
                           "orient": "right", "grid": true  }
                }
EOS
                    if IFrame['false'][:sel]
                        print <<EOS
                ,
                "opacity": {
                  "condition": {"param": "Vaxx", "value": 1},
                  "value": 0
                }
EOS
                    end
                    print <<EOS
              }
            }
EOS
                    end
                print <<EOS
          ]
        }
EOS
            end
        end
    end
end

print <<EOS
      ]
    };
    vegaEmbed("#vis", spec, {mode: "vega-lite"}).then(console.log).catch(console.warn);
  </script>
EOS

if IFrame['false'][:sel]
    print <<EOS
  <p class=r>
    © 2022 <a href="https://medicalfacts.info">MedicalFacts.info</a> powered by <a href="https://www.elastic.co/" target><img src="https://images.contentstack.io/v3/assets/bltefdd0b53724fa2ce/blt280217a63b82a734/5bbdaacf63ed239936a7dd56/elastic-logo.svg" style="height: 24pt; vertical-align: -6pt;"></a> <a href="https://vega.github.io/vega-lite/" style="text-decoration: none;"><img src="https://raw.githubusercontent.com/vega/logos/master/assets/VL_Color%40128.png" style="height: 20pt; vertical-align: -5pt; margin-right: -3rtpt;"> Vega-Lite</a>
  <p class=l>
  <hr>
    #{{'ja': 'データ元', en: 'Data sources'}[$l]}:
    <ul>
      <li> <a target=_blank href="https://www.mortality.org/Data/STMF"> Human Mortality Database, Short-Term Mortality Fluctuations</a>
      <li> <a target=_blank href="https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0"> e-Stat #{{ja: '統計で見る日本 人口動態統計 月報（概数） 月次', en: 'Statistics of Japan, Population Dynamics, Monthly Reports (Estimated)'}[$l]} </a>
      <li> <a target=_blank href="https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&tclass1=000001053058&tclass2=000001053061&tclass3=000001053074&tclass4=000001053089&cycle_facet=tclass1%3Atclass2%3Atclass3&tclass5val=0">e-Stat #{{ja: '統計で見る日本 人口動態統計 確定数 保管統計表　都道府県編（報告書非掲載表）死因 年次', en: 'Statistics of Japan, Population Dynamics, Prefectural Breakdown, Causes of Death, Annual Reports (Confirmed)'}[$l]}</a>
      <li> <a target=_blank href="https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0"> e-Stat #{{ja: '統計で見る日本 人口推計 各月1日現在人口 月次', en: 'Statistics of Japan, Population Estimation, As of the 1st of Each Month, Monthly Reports (Estimated and Confirmed)'}[$l]}</a>
    </ul>
  </div>
</body>
</html>
EOS
end
