#!/usr/bin/ruby
# coding: utf-8

require 'cgi'
require 'date'
require 'json'
require 'pp'
require_relative 'lib/mfacts'

#
# The oldest/newest year
#
$oldest = 2009
$newest = 2026

CauseCodes = {
    'total' => '00000',
    'cancer' => '02000',
    'circulatory' => '09000',
    'respiratory' => '10000',
    'senility' => '18000',
    'covid19' => '22200',
    'cirvical' => '02113',
    'influenza' => '10100',
    'suicide' => '20200',
}.freeze

SexCodes = {
    'b' => 'both',
    'm' => 'male',
    'f' => 'female',
}.freeze

AgeFields = {
    'all' => 'age_all',
    '0' => 'age_0',
    '1' => 'age_1',
    '2' => 'age_2',
    '3' => 'age_3',
    '4' => 'age_4',
    '100_' => 'age_100over',
    'shogaku' => 'age_elementary',
    'chugaku' => 'age_junior',
}.freeze

SliderAgeKeys = %w[
    00_04 05_09 10_14 15_19 20_24 25_29 30_34 35_39 40_44 45_49
    50_54 55_59 60_64 65_69 70_74 75_79 80_84 85_89 90_94 95_99 100_
].freeze

#
# CGI.new
#
$cgi = CGI.new

lang = $cgi['l']
if (lang =~ /^(en|english)/i) ||
   (lang == '' && ENV['HTTP_ACCEPT_LANGUAGE'].to_s !~ /^ja/)
    $l = :en
    $echeck = 'checked'
    $jcheck = ''
else
    $l = :ja
    $echeck = ''
    $jcheck = 'checked'
end

PageTitle = {
    ja: '日本の主な死因別死者推移',
    en: 'Trends in Deaths by Major Cause in Japan',
}.freeze

if $oldest <= $cgi['year'].to_i && $cgi['year'].to_i <= $newest
    $oldest = $start = $cgi['year']
else
    $start = 2009
end

#
# iFrame
#
$iframeflag = ($cgi['i'] == '1' || $cgi['i'] == 'true') ? true : false

#
# Height
#
$height = ($cgi['height'] != '' && $cgi['height'].to_i >= 100) ? $cgi['height'].to_i : 200

#
# Width
#
$width = ($cgi['width'] != '') ? $cgi['width'] : '80%'

#
# Causes
#
$causes = {
    'total' => {
        ja: '1. 全死因',
        en: '1. All causes',
        max: 0,
    },
    'cancer' => {
        ja: '2. 癌',
        en: '2. Cancer',
        max: 0,
    },
    'circulatory' => {
        ja: '3. 循環器系疾患',
        en: '3. Circulatory diseases',
        max: 0,
    },
    'respiratory' => {
        ja: '4. 呼吸器系疾患',
        en: '4. Respiratory diseases',
        max: 0,
    },
    'senility' => {
        ja: '5. 老衰・突然死',
        en: '5. Senility and ill-defined causes',
        max: 0,
    },
    'covid19' => {
        ja: '6. 新型コロナ',
        en: '6. COVID-19',
        max: 0,
    },
    'cirvical' => {
        ja: '6. 子宮癌',
        en: '6. Uterine cancer',
        max: 0,
    },
    'influenza' => {
        ja: '6. インフル',
        en: '6. Influenza',
        max: 0,
    },
    'suicide' => {
        ja: '7. 自殺',
        en: '7. Suicide',
        max: 0,
    },
}

$ages = {
    'all' => {
        sel: '',
        ja: '全年齢'
    },
    '0' => {
        sel: '',
        ja: '0歳',
        avg: 0.5,
    },
    '1' => {
        sel: '',
        ja: '1歳',
        avg: 1.5,
    },
    '2' => {
        sel: '',
        ja: '2歳',
        avg: 2.5,
    },
    '3' => {
        sel: '',
        ja: '3歳',
        avg: 3.5,
    },
    '4' => {
        sel: '',
        ja: '4歳',
        avg: 4.5,
    },
    '00_04' => {
        sel: '',
        ja: '0-4歳',
        avg: 2.5,
    },
    '05_09' => {
        sel: '',
        ja: '5-9歳',
        avg: 7.5,
    },
    '10_14' => {
        sel: '',
        ja: '10-14歳',
        avg: 12.5,
    },
    '15_19' => {
        sel: '',
        ja: '15-19歳',
        avg: 17.5,
    },
    '20_24' => {
        sel: '',
        ja: '20-24歳',
        avg: 22.5,
    },
    '25_29' => {
        sel: '',
        ja: '25-29歳',
        avg: 27.5,
    },
    '30_34' => {
        sel: '',
        ja: '30-34歳',
        avg: 32.5,
    },
    '35_39' => {
        sel: '',
        ja: '35-39歳',
        avg: 37.5,
    },
    '40_44' => {
        sel: '',
        ja: '40-44歳',
        avg: 42.5,
    },
    '45_49' => {
        sel: '',
        ja: '45-49歳',
        avg: 47.5,
    },
    '50_54' => {
        sel: '',
        ja: '50-54歳',
        avg: 52.5,
    },
    '55_59' => {
        sel: '',
        ja: '55-59歳',
        avg: 57.5,
    },
    '60_64' => {
        sel: '',
        ja: '60-64歳',
        avg: 62.5,
    },
    '65_69' => {
        sel: '',
        ja: '65-69歳',
        avg: 67.5,
    },
    '70_74' => {
        sel: '',
        ja: '70-74歳',
        avg: 72.5,
    },
    '75_79' => {
        sel: '',
        ja: '75-79歳',
        avg: 77.5,
    },
    '80_84' => {
        sel: '',
        ja: '80-84歳',
        avg: 82.5,
    },
    '85_89' => {
        sel: '',
        ja: '85-89歳',
        avg: 87.5,
    },
    '90_94' => {
        sel: '',
        ja: '90-94歳',
        avg: 92.5,
    },
    '95_99' => {
        sel: '',
        ja: '95-99歳',
        avg: 97.5,
    },
    '100_' => {
        sel: '',
        ja: '100歳以上',
        avg: 102.5,
    },
    'unknown' => {
        sel: '',
        ja: '不明',
    },
    'shogaku' => {
        sel: '',
        ja: '小学生年齢',
    },
    'chugaku' => {
        sel: '',
        ja: '中学生年齢',
    },
}

$ages.each do |key, value|
    value[:en] = case key
                 when 'all' then 'All ages'
                 when 'unknown' then 'Unknown'
                 when 'shogaku' then 'Elementary school age'
                 when 'chugaku' then 'Junior high school age'
                 when '100_' then '100 years and over'
                 when /^\d$/ then "#{key} year"
                 else
                     first, last = key.split('_').map(&:to_i)
                     "#{first}–#{last} years"
                 end
end

#
# 年齢選択
#
if $cgi['all'] == 'true'
    $ages.each do |k, v|
        if k == 'all'
            v[:sel] = 'checked'
            next
        end
        v[:sel] = ''
    end
elsif $cgi['shogaku'] == 'true' || $cgi['chugaku'] == 'true'
    $ages.each do |k, v|
        if k == 'shogaku' && $cgi['shogaku'] == 'true'
            v[:sel] = 'checked'
            next
        end
        if k == 'chugaku' && $cgi['chugaku'] == 'true'
            v[:sel] = 'checked'
            next
        end
        v[:sel] = ''
    end
else
    $ages.each do |k, v|
        next if $cgi[k] != 'true'

        v[:sel] = 'checked'
    end
end

if ! $ages.find{|k, v| v[:sel] == 'checked'}
    $ages['all'][:sel] = 'checked'
end

if $ages['all'][:sel] == 'checked'
    $ages.each do |k, v|
        next if k == 'all'
        v[:sel] = ''
    end
end

ages = $ages.select{|k, v| v[:sel] == 'checked'}.keys

#
# 男女
#
$bcheck = ''
$mcheck = ''
$fcheck = ''
$appends = ['(', '(', '(']
$sex = $cgi['sex']
if $sex == 'f' || $cgi['red'] == 'cirvical'
    $sex = 'f'
    $fcheck = 'checked'
    $appends[2] = ($appends[1] = ($appends[0] += ($l == :ja ? '女性、' : 'Female, ')))
elsif $sex == 'm'
    $mcheck = 'checked'
    $appends[2] = ($appends[1] = ($appends[0] += ($l == :ja ? '男性、' : 'Male, ')))
else
    $sex = 'b'
    $bcheck = 'checked'
end

agestr = ''
if $l == :en
    agestr = ages.map{|age| $ages[age][:en]}.join(', ') + ', '
else
    ages.each do |age|
        if age == 'all'
            agestr += '全年齢、'
            break
        end
        if (agestr.slice(-3..-2).to_i + 1) == age.slice(0..1).to_i
            agestr = agestr.slice(0..-5) + '-' + age.slice(-2..-1) + ','
        elsif age == 'shogaku' || age == 'chugaku'
            agestr += "#{$ages[age][:ja]}、"
        else
            agestr += "#{age.gsub('_','-')},"
        end
    end
    agestr.gsub!(/,$/, '歳、') if agestr !~ /齢、$/
end

(0..2).each do |i|
    $appends[i] += agestr
end
$appends[0] += ($l == :ja ? '全死因・' : 'all causes, ')

#
# 自殺表示
#
if $cgi['suicide'] == 'true'
    $sflag = 'checked'
    $remove2 = ''
    (0..1).each do |i|
        $appends[i] += ($l == :ja ? '自殺・' : 'suicide, ')
    end
else
    $sflag = ''
    $remove2 = $causes['suicide'][$l]
end

#
# 平均年齢表示
#
if $cgi['avg'] == 'true'
    $aflag = 'checked'
end

#
# 呼吸器系疾患に新型コロナを含めるか
#
$c19addflag = ''
if $cgi['c19add'] == 'true' || $cgi['c19add'] == 1
    $c19addflag = 'checked'
end

#
# 赤線
#
$crvcheck = ''
$c19check = ''
if $cgi['red'] == 'cirvical'
    $red = 'cirvical'
    $crvcheck = 'checked'
    $remove0 = $causes['covid19'][$l]
    $remove1 = $causes['influenza'][$l]
    $appends[0] += ($l == :ja ? '子宮癌・' : 'uterine cancer, ')
    $appends[1] += ($l == :ja ? '癌・子宮癌のみ)' : 'cancer and uterine cancer only)')
    $appends[2] += ($l == :ja ? '癌・子宮癌のみ)' : 'cancer and uterine cancer only)')
elsif $cgi['red'] == 'influenza'
    $red = 'influenza'
    $infcheck = 'checked'
    $remove0 = $causes['covid19'][$l]
    $remove1 = $causes['cirvical'][$l]
    (0..2).each do |i|
        $appends[i] += ($l == :ja ? 'インフルエンザ・' : 'influenza, ')
    end
else
    $red = 'covid19'
    $c19check = 'checked'
    $remove0 = $causes['cirvical'][$l]
    $remove1 = $causes['influenza'][$l]
    (0..2).each do |i|
        $appends[i] += ($l == :ja ? '新型コロナ・' : 'COVID-19, ')
    end
end

(0..2).each do |i|
    if $l == :ja
        $appends[i].gsub!(/・$/, '含む)')
    else
        $appends[i].sub!(/, $/, ')')
    end
end


#
# Unit
#
$unit_key = 'month'
$unit = ($l == :ja ? '月' : 'month')
$timeunit = 'yearmonth'
$format = '%Y/%m'
$xtitle = ($l == :ja ? '月' : 'Month')
$monthcheck = 'checked'
$yearcheck = ''
if $cgi['unit'] == 'year'
    $unit_key = 'year'
    $unit = ($l == :ja ? '年' : 'year')
    $timeunit = 'year'
    $format = '%Y'
    $xtitle = ($l == :ja ? '年' : 'Year')
    $monthcheck = ''
    $yearcheck = 'checked'
end
$range_newest = $unit_key == 'year' ? $newest - 1 : $newest
$data_before = $unit_key == 'year' ? "#{$newest}-01-01" : 'now'

#
# Stroke Dash
#
$stroke == ''
if $cgi['stroke'] == 'dash'
    $stroke = "            \"strokeDash\": {\"title\": \"#{ {ja: '死因', en: 'Cause'}[$l] }\", \"field\": \"type\", \"type\": \"nominal\"},"
end

#
# Values
#
$vflag = ''
$opacityparam = '{ "name": "type2", "select": { "type": "point", "fields": ["type"] }, "bind": {"legend": "mouseover"} },'
$opacity = '"opacity": { "condition": {"param": "type2", "value": 1}, "value": 0.05 },'
if $cgi['values'] == 'true'
    $vflag = 'checked'
    $opacityparam = ''
    $opacity = ''
end

print_header(:title => PageTitle[$l], :iframe => $iframeflag)
print <<EOF
  <style>
    .range-selector { display: flex; align-items: center; gap: .8em; margin: .35em 0; }
    .range-panel { display: flex; align-items: center; gap: .7em; flex: 1; }
    [hidden] { display: none !important; }
    .dual-range { position: relative; min-width: 18em; max-width: 42em; height: 2.8em; flex: 1; }
    .dual-range::before { content: ""; position: absolute; left: 0; right: 0; top: .72em;
      height: .28em; border-radius: .2em; background: linear-gradient(to right,
      #bbb 0%, #bbb var(--low), #0676e8 var(--low), #0676e8 var(--high), #bbb var(--high), #bbb 100%); }
    .dual-range input[type="range"] { -webkit-appearance: none; appearance: none; position: absolute;
      left: 0; top: .15em; width: 100%; height: 1.4em; margin: 0; pointer-events: none; background: transparent; }
    .dual-range input[type="range"]::-webkit-slider-runnable-track { height: .28em; background: transparent; }
    .dual-range input[type="range"]::-moz-range-track { height: .28em; background: transparent; }
    .dual-range input[type="range"]::-webkit-slider-thumb { -webkit-appearance: none; appearance: none;
      pointer-events: auto; width: 1.2em; height: 1.2em; margin-top: -.46em; border: 2px solid white;
      border-radius: 50%; background: #666; box-shadow: 0 0 2px #333; }
    .dual-range input[type="range"]::-moz-range-thumb { pointer-events: auto; width: 1.2em; height: 1.2em;
      border: 2px solid white; border-radius: 50%; background: #666; box-shadow: 0 0 2px #333; }
    .range-ticks { position: absolute; left: 0; right: 0; top: 1.55em; height: 1.1em; }
    .range-tick { position: absolute; transform: translateX(-50%); font-size: .72em; color: #555; }
    .range-value { min-width: 8em; text-align: center; }
    .selector-switch { white-space: nowrap; }
    .checkbox-panel { line-height: 1.8; }
  </style>
  <script>
    const sliderAgeValues = #{JSON.generate(SliderAgeKeys)};
    const sliderAgeLabels = #{JSON.generate(SliderAgeKeys.map{|age| $ages[age][$l]})};
    const currentLanguage = #{JSON.generate($l.to_s)};
    function ageCheckboxes() { return Array.from(document.querySelectorAll('.age-checkbox')); }
    function updateAgeRangeLabel() {
      const min = Number(document.getElementById('age-range-min').value);
      const max = Number(document.getElementById('age-range-max').value);
      const first = Number(sliderAgeValues[min].slice(0, 2));
      const lastOver = sliderAgeValues[max] == '100_';
      const last = lastOver ? 100 : Number(sliderAgeValues[max].slice(0, 2)) + 4;
      document.getElementById('age-range-value').textContent =
        min == 0 && lastOver ? (currentLanguage == 'ja' ? '全年齢' : 'All ages') :
        (min == max ? sliderAgeLabels[min] :
        (lastOver ? (currentLanguage == 'ja' ? `${first}歳以上` : `${first}+ years`) :
        (currentLanguage == 'ja' ? `${first}–${last}歳` : `${first}–${last} years`)));
      const denominator = sliderAgeValues.length - 1;
      const range = document.querySelector('.dual-range');
      range.style.setProperty('--low', `${min * 100 / denominator}%`);
      range.style.setProperty('--high', `${max * 100 / denominator}%`);
    }
    function updateAgesFromRange(changed) {
      const minInput = document.getElementById('age-range-min');
      const maxInput = document.getElementById('age-range-max');
      if (Number(minInput.value) > Number(maxInput.value)) {
        if (changed == 'min') maxInput.value = minInput.value; else minInput.value = maxInput.value;
      }
      const min = Number(minInput.value), max = Number(maxInput.value);
      const full = min == 0 && max == sliderAgeValues.length - 1;
      ageCheckboxes().forEach(box => {
        const index = sliderAgeValues.indexOf(box.name);
        box.checked = box.name == 'all' ? full : (!full && index >= min && index <= max);
      });
      updateAgeRangeLabel();
    }
    function syncAgeRangeFromCheckboxes() {
      const all = document.querySelector('.age-checkbox[name="all"]');
      let indexes = ageCheckboxes().filter(box => box.checked).
        map(box => sliderAgeValues.indexOf(box.name)).filter(index => index >= 0);
      if (all.checked || indexes.length == 0) indexes = [0, sliderAgeValues.length - 1];
      document.getElementById('age-range-min').value = Math.min(...indexes);
      document.getElementById('age-range-max').value = Math.max(...indexes);
      updateAgeRangeLabel();
    }
    function showAgeMode(mode) {
      document.getElementById('age-slider-panel').hidden = mode != 'slider';
      document.getElementById('age-checkbox-panel').hidden = mode != 'checkbox';
      if (mode == 'slider') syncAgeRangeFromCheckboxes();
    }
    document.addEventListener('DOMContentLoaded', () => {
      const max = sliderAgeValues.length - 1;
      document.getElementById('age-range-min').max = max;
      document.getElementById('age-range-max').max = max;
      document.getElementById('age-range-max').value = max;
      const ticks = document.getElementById('age-range-ticks');
      sliderAgeValues.forEach((age, index) => {
        if (index % 2 != 0 && index != max) return;
        const tick = document.createElement('span'); tick.className = 'range-tick';
        tick.style.left = `${index * 100 / max}%`; tick.textContent = age == '100_' ? 100 : Number(age.slice(0, 2));
        ticks.appendChild(tick);
      });
      syncAgeRangeFromCheckboxes();
    });
  </script>
  <p class=c>
  <form action="#{CGI.escapeHTML(File.basename($PROGRAM_NAME))}" method="get" style="text-align: center;">
EOF

if ! $iframeflag
    print <<EOF
  <!-- <details>
    <summary>#{{ja: 'チェックボックス展開', en: 'Expand Checkboxes'}[$l]}</summary> -->
EOF

    print <<EOF
    <div class="range-selector">
      <span>#{{ja: '年齢', en: 'Age'}[$l]}</span>
      <div id="age-slider-panel" class="range-panel">
        <div class="dual-range">
          <input id="age-range-min" type="range" min="0" value="0" oninput="updateAgesFromRange('min')">
          <input id="age-range-max" type="range" min="0" value="0" oninput="updateAgesFromRange('max')">
          <div id="age-range-ticks" class="range-ticks"></div>
        </div>
        <span id="age-range-value" class="range-value"></span>
        <button type="button" class="selector-switch" onclick="showAgeMode('checkbox')">#{{ja: 'チェックボックスに切替え', en: 'Switch to checkboxes'}[$l]}</button>
      </div>
      <div id="age-checkbox-panel" class="checkbox-panel" hidden>
EOF
    $ages.each do |k, v|
        print <<EOF
    <span><input class="age-checkbox" type="checkbox" name="#{k}" value="true" #{v[:sel]}
                 onchange="syncAgeRangeFromCheckboxes()"> #{v[$l]}</span>
EOF
end

print <<EOF
        <button type="button" class="selector-switch" onclick="showAgeMode('slider')">#{{ja: 'スライダーに切替え', en: 'Switch to sliders'}[$l]}</button>
      </div>
    </div>
  <!-- </details> -->
    <br>
    <span>
      <input type="radio" name="unit" value="month" #{$monthcheck}>#{{ja: '月ごと', en: 'Monthly'}[$l]}
      <input type="radio" name="unit" value="year" #{$yearcheck}>#{{ja: '年ごと', en: 'Yearly'}[$l]}
    </span>
    <span>
      <input type="radio" name="sex" value="b" #{$bcheck}>#{{ja: '男女', en: 'Both'}[$l]}
      <input type="radio" name="sex" value="m" #{$mcheck}>#{{ja: '男性', en: 'Male'}[$l]}
      <input type="radio" name="sex" value="f" #{$fcheck}>#{{ja: '女性', en: 'Female'}[$l]}
    </span>
    <span>
      <input type="radio" name="red" value="covid19" #{$c19check}>#{{ja: '新型コロナ', en: 'COVID-19'}[$l]}
      <input type="radio" name="red" value="cirvical" #{$crvcheck}>#{{ja: '子宮癌', en: 'Uterine cancer'}[$l]}
      <input type="radio" name="red" value="influenza" #{$infcheck}>#{{ja: 'インフルエンザ', en: 'Influenza'}[$l]}
    </span>
    <span><input type="checkbox" name="suicide" value="true" #{$sflag}>#{{ja: '自殺', en: 'Suicide'}[$l]}</span>
    <span><input type="checkbox" name="avg" value="true" #{$aflag}>#{{ja: '平均年齢', en: 'Average age'}[$l]}</span>
    <span><input type="checkbox" name="values" value="true" #{$vflag}>#{{ja: '値表示', en: 'Show values'}[$l]}</span>
    <span><input type="checkbox" name="c19add" value="true" #{$c19addflag}>#{{ja: '呼吸器系疾患に新型コロナを含める', en: 'Include COVID-19 in respiratory diseases'}[$l]}</span>
    <span><input type="radio" name="l" value="ja" #{$jcheck}>日本語</span>
    <span><input type="radio" name="l" value="en" #{$echeck}>English</span>
    <input type="submit" value="送信/Submit" />
    <input type="hidden" name="i" value="#{$iframeflag}">
  </form>
EOF
end

if $l == :ja
print <<EOF
  <p class=c>
  <span>
  <span style="font-weight: bold; color: #0000ff;">青色</span>は全死因、
  <span style="font-weight: bold; color: #000080;">紺色</span>は癌、
  <span style="font-weight: bold; color: #ff00ff;">紫色</span>は循環器系疾患、
  <span style="font-weight: bold; color: #d04000;">橙色</span>は呼吸器系疾患、
  </span>
  <span>
  <span style="font-weight: bold; color: #700000;">茶色</span>は老衰・突然死、
  <span style="font-weight: bold; color: #f00000;">赤色</span>は#{$causes[$red][$l].slice(3,99)}、
  <span style="font-weight: bold; color: #000000;">黒色</span>は自殺
  </span>
EOF
else
print <<EOF
  <p class=c>
  <span><b style="color:#0000ff">Blue</b>: all causes; <b style="color:#000080">navy</b>: cancer;
  <b style="color:#ff00ff">purple</b>: circulatory diseases; <b style="color:#d04000">orange</b>: respiratory diseases;</span>
  <span><b style="color:#700000">brown</b>: senility and ill-defined causes;
  <b style="color:#f00000">red</b>: #{$causes[$red][$l].sub(/^\d+\. /, '')}; <b style="color:#000000">black</b>: suicide.</span>
EOF
end
print <<EOF
  <p class=l>
  <div id="vis" style="width: #{$width}; text-align: left;">
  <span id="blink1223" style="font-size: large; font-weight: bold;">#{{ja: '読込中...', en: 'Loading...'}[$l]}</span><script>with(blink1223)id='',style.opacity=1,setInterval(function(){style.opacity^=1},500)</script>
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
        #{$opacityparam}
        {
          "name": "start_year",
          "value": #{$start},
          "bind": {"input": "range", "min": #{$oldest}, "max": #{$range_newest}, "step": 1 }
        }
      ],
      "data": {
EOF
print '        "values": '

#
# ElasticSearch
#

death_codes = $causes.keys.map{|type| CauseCodes.fetch(type)}
source_age_fields = $ages.keys.map{|age| AgeFields.fetch(age, "age_#{age}")}

data0 = elastic_search(
    :index => 'mstats',
    :filter => [
        { 'range' => {'date' => {'gte' => "#{$oldest}-01-01", 'lt' => $data_before } } },
        { 'term' => {'category' => 'death'} },
        { 'term' => {'loc_code' => 'jpn'} },
        { 'term' => {'sex' => SexCodes.fetch($sex)} },
    ],
    :should => death_codes.map{|code| {'term' => {'death_code' => code}}},
    :source => ['date', 'sex', 'death_code'] + source_age_fields,
)

date_covid19 = Date.parse('2020-01-01')
max_date = date_covid19

data = Array.new

data0.each do |datum|
    date = Date.parse(datum[:date])
    max_date = date > max_date ? date : max_date

    deaths = 0
    ages.each do |age|
        deaths += datum[AgeFields.fetch(age, "age_#{age}").to_sym].to_i
    end

    # average
    total_deaths = 0
    total_ages = 0.0
    $ages.each do |k, v|
        age_value = datum[AgeFields.fetch(k, "age_#{k}").to_sym]
        if v[:avg] && age_value && age_value.to_i > 0
            total_deaths += age_value.to_i
            total_ages += age_value.to_i * v[:avg]
        end
    end

    cause_type = CauseCodes.key(datum[:death_code])
    next if ! cause_type

    data.push({'date' => date.to_s,
                'type' => $causes[cause_type][$l],
                'deaths' => deaths,
                'total_deaths' => total_deaths,
                'total_ages' => total_ages,
                'avg' => (total_ages > 0 && total_deaths > 0) ?
                             (total_ages / total_deaths).round(2) : nil})
    #if data.last['type'] == "6. 新型コロナ"
    #    pp data.last
    #end
end

# The legacy causes index stored explicit zero rows before a cause code appeared.
# Complete the same month/cause grid so Vega draws those series identically.
dates = data.select{|datum| datum['type'] == $causes['total'][$l]}.
             map{|datum| datum['date']}
existing = data.to_h{|datum| [[datum['date'], datum['type']], true]}
dates.each do |date|
    $causes.each_value do |cause|
        next if existing[[date, cause[$l]]]
        data.push({
            'date' => date,
            'type' => cause[$l],
            'deaths' => 0,
            'total_deaths' => 0,
            'total_ages' => 0.0,
            'avg' => nil,
        })
    end
end
data.sort_by!{|datum| [datum['date'], datum['type']]}
#exit

$xtitle += if $l == :ja
               " (#{max_date.strftime('%Y年%m月')}まで)"
           else
               " (through #{max_date.strftime('%B %Y')})"
           end
$trend_title = PageTitle[$l]
$avg_title = {ja: '日本の死者平均年齢推計', en: 'Estimated Average Age at Death in Japan'}[$l]
$deaths_axis_title = {ja: "#{$unit}ごとの死者数", en: "Deaths per #{$unit}"}[$l]
$average_axis_title = {ja: "#{$unit}ごとの死者の平均年齢", en: "Average age at death per #{$unit}"}[$l]
$cause_axis_title = {ja: '死因', en: 'Cause'}[$l]
#pp $xtitle
#exit

if $c19addflag == 'checked'
    data.each do |datum|
        if datum['type'] == $causes['covid19'][$l] && datum['deaths']
            datum2 = data.find {|v| v['date'] == datum['date'] &&
                                     v['type'] == $causes['respiratory'][$l] }
            #puts '+++++++++++++++++++++'
            #pp datum, datum2
            datum2['deaths'] += datum['deaths']
            #pp datum, datum2
        end
    end
end
#exit

puts JSON.pretty_generate(data).gsub(/\n/, "\n        ")

print <<EOF
      },
      "vconcat": [
EOF

# 死因別推移の平均系列を出力する。
# Render the average series for cause-of-death trends.
def print_avg
    print <<EOF
        {
          "title": {
            "text": ["#{$avg_title} #{$appends[0]}"],
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "transform": [
            {
              "filter": {
                "field": "date",
                "range": [
                  {"year": #{$oldest}, "month": "jan", "date": 1},
                  {"expr": "now()"}
                ]
              }
            },
            { "filter": "datum.avg != null" },
            { "filter": "datum.type != \'#{$remove0}\'" },
            { "filter": "datum.type != \'#{$remove1}\'" },
            { "filter": "datum.type != \'#{$remove2}\'" }
          ],
          "mark": {"type": "line", "clip": true},
          "encoding": {
            "x": {
              "title": ["#{$xtitle}", "", "#{$appends[3]}", "#{$appends[4]}"],
              "field": "date",
              "type": "temporal",
              "timeUnit": "#{$timeunit}",
              "axis": {"format": "#{$format}"},
              "scale": {
                "domain": [
                  {"year": "start_year", "month": "jan", "date": 1},
                  {"expr": "now()"}
                ]
              }
            },
            "y": {
              "title": "#{$average_axis_title}",
              "field": "avg",
              "type": "quantitative",
              "aggregate": "average",
              "scale": {"domain": [50, 100]}
            },
            "color": {
              "scale": {
                "range": [
                  "#0000ff", "#000080", "#ff00ff", "#d04000", "#700000", "#f00000", "#000000"
                ]
              },
              "title": "#{$cause_axis_title}",
              "field": "type",
              "type": "nominal"
            },
            #{$stroke}
            #{$opacity}
            "tooltip": {"field": "avg", "type": "quantitative", "aggregate": "average"}
          }
EOF
end

$firstflag = true
# Vega-Liteグラフ定義の共通末尾を出力する。
# Render the shared closing section of a Vega-Lite chart specification.
def print_tails
    print <<EOF
          "encoding": {
            "x": {
              "title": "#{$xtitle}",
              "field": "date",
              "type": "temporal",
              "timeUnit": "#{$timeunit}",
              "axis": {"format": "#{$format}"},
              "scale": {
                "domain": [
                  {"year": "start_year", "month": "jan", "date": 1},
                  {"expr": "now()"}
                ]
              }
            },
            "y": {
              "title": "#{$deaths_axis_title}",
              "field": "deaths",
              "type": "quantitative",
              "aggregate": "sum"
            },
            "color": {
              "title": "#{$cause_axis_title}",
              "field": "type",
EOF
    if $firstflag == true
        print <<EOF
              "scale": {
                "range": [
                  "#0000ff", "#000080", "#ff00ff", "#d04000", "#700000", "#f00000", "#000000"
                ]
              },
EOF
    end
print <<EOF
              "type": "nominal"
            },
            #{$stroke}
            #{$opacity}
            "tooltip": {"field": "deaths", "type": "quantitative", "aggregate": "sum"}
          },
          "layer": [
            {
              "mark": {"type": "line", "clip": true}
            }
EOF
    if $vflag == 'checked'
        print <<EOF
            , {
              "mark": {
                "type": "text",
                "align": "left",
                "baseline": "bottom",
                "dy": -2,
                "fontSize": 14
              },
              "encoding": {
                "text": {
                  "field": "deaths",
                  "type": "quantitative",
                  "aggregate": "sum"
                }
              }
            }
EOF
    end
    print <<EOF
          ]
EOF
end

# 全死因の推移グラフを出力する。
# Render the all-cause trend chart.
def print_all
    print <<EOF
        {
          "title": {
            "text": "#{$trend_title} #{$appends[0]}",
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "transform": [
            {
              "filter": {
                "field": "date",
                "range": [
                  {"year": #{$oldest}, "month": "jan", "date": 1},
                  {"expr": "now()"}
                ]
              }
            },
            { "filter": "datum.type != \'#{$remove0}\'" },
            { "filter": "datum.type != \'#{$remove1}\'" },
            { "filter": "datum.type != \'#{$remove2}\'" }
          ],
EOF
    print_tails
end

# COVID-19を含む死因推移グラフを出力する。
# Render the cause-of-death trend chart including COVID-19.
def print_covid19
    print <<EOF
        },
        {
          "title": {
            "text": "#{$trend_title} #{$appends[1]}",
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "transform": [
            {
              "filter": {
                "field": "date",
                "range": [
                  {"year": #{$oldest}, "month": "jan", "date": 1},
                  {"expr": "now()"}
                ]
              }
            },
            { "filter": "datum.type != \'#{$remove0}\'" },
            { "filter": "datum.type != \'#{$remove1}\'" },
            { "filter": "datum.type != \'#{$causes['total'][$l]}\'" }
          ],
EOF
    print_tails
end

# その他を除いたCOVID-19関連の死因推移を出力する。
# Render COVID-19-related cause trends excluding residual categories.
def print_covid19_except_others
    print <<EOF
        },
        {
          "title": {
            "text": "#{$trend_title} #{$appends[2]}",
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "transform": [
            {
              "filter": {
                "field": "date",
                "range": [
                  {"year": #{$oldest}, "month": "jan", "date": 1},
                  {"expr": "now()"}
                ]
              }
            },
            { "filter": "datum.type != \'#{$causes['suicide'][$l]}\'" },
            { "filter": "datum.type != \'#{$remove0}\'" },
            { "filter": "datum.type != \'#{$remove1}\'" },
            { "filter": "datum.type != \'#{$causes['total'][$l]}\'" }
          ],
EOF
    print_tails
end

# 子宮頸がんを含む関連死因の推移を出力する。
# Render trends for cervical cancer and related causes.
def print_cirvical
        print <<EOF
        },
        {
          "title": {
            "text": "#{$trend_title} #{$appends[1]}",
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "transform": [
            {
              "filter": {
                "field": "date",
                "range": [
                  {"year": #{$oldest}, "month": "jan", "date": 1},
                  {"expr": "now()"}
                ]
              }
            },
            { "filter": "datum.type != \'#{$causes['circulatory'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['respiratory'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['senility'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['covid19'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['influenza'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['total'][$l]}\'" }
          ],
EOF
        print_tails
end

# その他を除いた子宮頸がん関連死因の推移を出力する。
# Render cervical-cancer-related trends excluding residual categories.
def print_cirvical_except_others
    print <<EOF
        },
        {
          "title": {
            "text": "#{$trend_title} #{$appends[2]}",
            "anchor": "start"
          },
          "height": #{$height},
          "width": "container",
          "transform": [
            {
              "filter": {
                "field": "date",
                "range": [
                  {"year": #{$oldest}, "month": "jan", "date": 1},
                  {"expr": "now()"}
                ]
              }
            },
            { "filter": "datum.type != \'#{$causes['circulatory'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['respiratory'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['senility'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['suicide'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['covid19'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['influenza'][$l]}\'" },
            { "filter": "datum.type != \'#{$causes['total'][$l]}\'" }
          ],
EOF
    print_tails
end

datum_c = data.find { |d| d['date'] == '2020-09-01' && d['type'] == $causes['cancer'][$l]}
datum_s = data.find { |d| d['date'] == '2020-09-01' && d['type'] == $causes['suicide'][$l]}

#pp datum_c, datum_s
#exit

if $aflag == 'checked'
    $appends[3] = ''
    $appends[4] = ''
    if $red == 'influenza'
        years = ['2019', '2018', '2017', '2016', '2015']
    else
        years = ['2022', '2021', '2020']
    end
    $appends[3] = $l == :ja ? '年ごとのコロナ死者平均年齢: ' : 'Annual average age of COVID-19 deaths: '
    years.each do |year|
        data2 = data.select { |d| d['date'] =~ /^#{year}.*$/ &&
                              d['type'] == $causes[$red][$l] }
        #pp data2
        total_deaths = data2.sum { |d| d['total_deaths'] }
        total_ages = data2.sum { |d| d['total_ages'] }
        avg = (total_ages.to_f/total_deaths).round(2)
        #pp avg
        $appends[3] += ($l == :ja ? '、' : ', ') if year != '2022' && year != '2019'
        $appends[3] += $l == :ja ? "#{year}年#{format('%.2f', avg)}歳" : "#{year}: #{format('%.2f', avg)} years"
    end
    $appends[4] = $l == :ja ? '年ごとの全死因死者平均年齢: ' : 'Annual average age of all deaths: '
    years.each do |year|
        data2 = data.select { |d| d['date'] =~ /^#{year}.*$/ &&
                              d['type'] == $causes['total'][$l] }
        #pp data2
        total_deaths = data2.sum { |d| d['total_deaths'] }
        total_ages = data2.sum { |d| d['total_ages'] }
        avg = (total_ages.to_f/total_deaths).round(2)
        #pp avg
        $appends[4] += ($l == :ja ? '、' : ', ') if year != '2022' && year != '2019'
        $appends[4] += $l == :ja ? "#{year}年#{format('%.2f', avg)}歳" : "#{year}: #{format('%.2f', avg)} years"
    end
    if $l == :ja && $red == 'cirvical'
        $appends[3].gsub!(/コロナ/, '子宮癌')
    elsif $l == :ja && $red == 'influenza'
        $appends[3].gsub!(/のコロナ/, 'インフル')
    end
    print_avg
else

print_all

if $red == 'cirvical'
    if $sflag == 'checked' && datum_s['deaths'] > datum_c['deaths'] * 1.5
        print_cirvical
    end
    print_cirvical_except_others
else
    if $sflag == 'checked' && datum_s['deaths'] > datum_c['deaths'] * 1.5
        print_covid19
    end
    print_covid19_except_others
end
end

print <<EOF
        }
      ]
    };
    vegaEmbed("#vis", spec, {mode: "vega-lite"}).then(console.log).catch(console.warn);
  </script>
EOF
if ! $iframeflag
    print <<EOF
  <p class=r>
    © 2022 <a href="https://medicalfacts.info">MedicalFacts.info</a> powered by <a href="https://www.elastic.co/" target><img src="https://images.contentstack.io/v3/assets/bltefdd0b53724fa2ce/blt280217a63b82a734/5bbdaacf63ed239936a7dd56/elastic-logo.svg" style="height: 2em"></a> <a href="https://vega.github.io/vega-lite/" style="text-decoration: none;"><img src="https://raw.githubusercontent.com/vega/logos/master/assets/VL_Color%40128.png" style="width: 2em;"> Vega-Lite</a>
  <hr>
  <p class=l>
    #{{ja: 'データ元', en: 'Data source'}[$l]}:
    <ul>
      <li> <a target=_blank href="https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0">#{{ja: 'e-Stat 人口動態統計 月報（概数）', en: 'e-Stat, Vital Statistics, Monthly Report (Preliminary)'}[$l]}</a>
EOF
    if $aflag == 'checked'
        print <<EOF
      <li> #{{ja: '推計にあたり区分年齢の平均値を使用して計算。つまり「10歳以上15歳未満」の区分なら12.5歳とした。例外的に「100歳以上」の区分は102.5歳とした。', en: 'Average age is estimated using each age group midpoint; the 100-and-over group is represented by 102.5 years.'}[$l]}
EOF
    end
    print <<EOF
    </ul>
  </div>
</body>
</html>
EOF
end
