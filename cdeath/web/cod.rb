#!/usr/bin/ruby
# coding: utf-8
# ruby-indent-level: 4
#

require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require 'date'
require_relative 'lib/mfacts'

#
# 年齢
#
Ages = {
    'all' => { sel: '', ja: '全年齢', en: 'All ages'},
#    '0' => { sel: '', ja: '0歳', en: '0yo', avg: 0.5 },
#    '1' => { sel: '', ja: '1歳', en: '1yo', avg: 1.5 },
#    '2' => { sel: '', ja: '2歳', en: '2yo', avg: 2.5 },
#    '3' => { sel: '', ja: '3歳', en: '3yo', avg: 3.5 },
#    '4' => { sel: '', ja: '4歳', en: '4yo', avg: 4.5 },
    '00_04' => { sel: '', ja: '0-4歳', en: '0-4yo', avg: 2.5 },
    '05_09' => { sel: '', ja: '5-9歳', en: '5-9yo', avg: 7.5 },
    '10_14' => { sel: '', ja: '10-14歳', en: '10-14yo', avg: 12.5 },
    '15_19' => { sel: '', ja: '15-19歳', en: '15-19yo', avg: 17.5 },
    '20_24' => { sel: '', ja: '20-24歳', en: '20-24yo', avg: 22.5 },
    '25_29' => { sel: '', ja: '25-29歳', en: '25-29yo', avg: 27.5 },
    '30_34' => { sel: '', ja: '30-34歳', en: '30-34yo', avg: 32.5 },
    '35_39' => { sel: '', ja: '35-39歳', en: '35-39yo', avg: 37.5 },
    '40_44' => { sel: '', ja: '40-44歳', en: '40-44yo', avg: 42.5 },
    '45_49' => { sel: '', ja: '45-49歳', en: '45-49yo', avg: 47.5 },
    '50_54' => { sel: '', ja: '50-54歳', en: '50-54yo', avg: 52.5 },
    '55_59' => { sel: '', ja: '55-59歳', en: '55-59yo', avg: 57.5 },
    '60_64' => { sel: '', ja: '60-64歳', en: '60-64yo', avg: 62.5 },
    '65_69' => { sel: '', ja: '65-69歳', en: '65-69yo', avg: 67.5 },
    '70_74' => { sel: '', ja: '70-74歳', en: '70-74yo', avg: 72.5 },
    '75_79' => { sel: '', ja: '75-79歳', en: '75-79yo', avg: 77.5 },
    '80_84' => { sel: '', ja: '80-84歳', en: '80-84yo', avg: 82.5 },
    '85_89' => { sel: '', ja: '85-89歳', en: '85-89yo', avg: 87.5 },
    '90_94' => { sel: '', ja: '90-94歳', en: '90-94yo', avg: 92.5 },
    '95_99' => { sel: '', ja: '95-99歳', en: '95-99yo', avg: 97.5 },
    '100over' => { sel: '', ja: '100歳以上', en: '100over', avg: 102.5 },
    'unknown' => { sel: '', ja: '不明',  en: 'unknown' },
    'elementary' => { sel: '', ja: '小学生年齢', en: 'Elementary school age' },
    'junior' => { sel: '', ja: '中学生年齢', en: 'Junior high school age' },
}
StandardAgeKeys = Ages.keys - ['all', 'unknown', 'elementary', 'junior']
OldestAgeKeys = %w[85_89 90_94 95_99 100over]
# 平成27年（2015年）モデル人口。死亡率計算では0〜4歳を結合し、
# 95歳以上も一階級として扱う。
# https://www.e-stat.go.jp/stat-search/file-download?fileKind=2&statInfId=000032172746
StandardPopulation2015 = {
    '00_04' => 5_026_000,
    '05_09' => 5_369_000,
    '10_14' => 5_711_000,
    '15_19' => 6_053_000,
    '20_24' => 6_396_000,
    '25_29' => 6_738_000,
    '30_34' => 7_081_000,
    '35_39' => 7_423_000,
    '40_44' => 7_766_000,
    '45_49' => 8_108_000,
    '50_54' => 8_451_000,
    '55_59' => 8_793_000,
    '60_64' => 9_135_000,
    '65_69' => 9_246_000,
    '70_74' => 7_892_000,
    '75_79' => 6_306_000,
    '80_84' => 4_720_000,
    '85_89' => 3_134_000,
    '90_94' => 1_548_000,
    '95over' => 423_000,
}

#
# 年
#
Years = {
    '2009' => {sel: ''},
    '2010' => {sel: ''},
    '2011' => {sel: ''},
    '2012' => {sel: ''},
    '2013' => {sel: ''},
    '2014' => {sel: ''},
    '2015' => {sel: ''},
    '2016' => {sel: ''},
    '2017' => {sel: ''},
    '2018' => {sel: ''},
    '2019' => {sel: ''},
    '2020' => {sel: ''},
    '2021' => {sel: ''},
    '2022' => {sel: ''},
    '2023' => {sel: ''},
    '2024' => {sel: ''},
    '2025' => {sel: ''},
}

#
# 症例
#
Death_codes = {
    'all'   => {sel: '', ja: '全死因', en: 'All cause'},
    '01000' => {sel: '', ja: '感染症及び寄生虫症', en: 'Infectious and parasitic diseases'},
    '01100' => {sel: '', ja: '腸管感染症', en: 'Intestinal infections'},
    '01200' => {sel: '', ja: '結核', en: 'Tuberculosis'},
    '01201' => {sel: '', ja: '呼吸器結核', en: 'Respiratory tuberculosis'},
    '01202' => {sel: '', ja: 'その他の結核', en: 'Other tuberculosis'},
    '01300' => {sel: '', ja: '敗血症', en: 'Sepsis'},
    '01400' => {sel: '', ja: 'ウイルス性肝炎', en: 'Viral hepatitis'},
    '01401' => {sel: '', ja: 'Ｂ型ウイルス性肝炎', en: 'Hepatitis B'},
    '01402' => {sel: '', ja: 'Ｃ型ウイルス性肝炎', en: 'Hepatitis C'},
    '01403' => {sel: '', ja: 'その他のウイルス性肝炎', en: 'Other viral hepatitis'},
    '01500' => {sel: '', ja: 'ヒト免疫不全ウイルス［ＨＩＶ］病', en: 'Human immunodeficiency virus [HIV] disease'},
    '01600' => {sel: '', ja: 'その他の感染症及び寄生虫症', en: 'Other infectious and parasitic diseases'},
    '02000' => {sel: '', ja: '新生物＜腫瘍＞', en: 'Neoplasms'},
    '02100' => {sel: '', ja: '悪性新生物＜腫瘍＞', en: 'Malignant neoplasms'},
    '02101' => {sel: '', ja: '口唇、口腔及び咽頭の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of lip, oral cavity, and pharynx'},
    '02102' => {sel: '', ja: '食道の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of esophagus'},
    '02103' => {sel: '', ja: '胃の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of stomach'},
    '02104' => {sel: '', ja: '結腸の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of colon'},
    '02105' => {sel: '', ja: '直腸Ｓ状結腸移行部及び直腸の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of rectosigmoid junction and rectum'},
    '02106' => {sel: '', ja: '肝及び肝内胆管の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of liver and intrahepatic bile ducts'},
    '02107' => {sel: '', ja: '胆のう及びその他の胆道の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of gallbladder and other parts of biliary tract'},
    '02108' => {sel: '', ja: '膵の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of pancreas'},
    '02109' => {sel: '', ja: '喉頭の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of larynx'},
    '02110' => {sel: '', ja: '気管、気管支及び肺の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of trachea, bronchus, and lung'},
    '02111' => {sel: '', ja: '皮膚の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of skin'},
    '02112' => {sel: '', ja: '乳房の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of breast'},
    '02113' => {sel: '', ja: '子宮の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of cervix uteri'},
    '02114' => {sel: '', ja: '卵巣の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of ovary'},
    '02115' => {sel: '', ja: '前立腺の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of prostate'},
    '02116' => {sel: '', ja: '膀胱の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of bladder'},
    '02117' => {sel: '', ja: '中枢神経系の悪性新生物＜腫瘍＞', en: 'Malignant neoplasms of central nervous system'},
    '02118' => {sel: '', ja: '悪性リンパ腫', en: 'Malignant lymphomas'},
    '02119' => {sel: '', ja: '白血病', en: 'Leukemia'},
    '02120' => {sel: '', ja: 'その他のリンパ組織、造血組織及び関連組織の悪性新生物＜腫瘍＞', en: 'Other malignant neoplasms of lymphoid, hematopoietic and related tissue'},
    '02121' => {sel: '', ja: 'その他の悪性新生物＜腫瘍＞', en: 'Other malignant neoplasms'},
    '02200' => {sel: '', ja: 'その他の新生物＜腫瘍＞', en: 'Other neoplasms'},
    '02201' => {sel: '', ja: '中枢神経系のその他の新生物＜腫瘍＞', en: 'Other neoplasms of central nervous system'},
    '02202' => {sel: '', ja: '中枢神経系を除くその他の新生物＜腫瘍＞', en: 'Other neoplasms excl. central nervous system'},
    '03000' => {sel: '', ja: '血液及び造血器の疾患並びに免疫機構の障害', en: 'Blood and hematopoietic organ diseases and immune system disorders'},
    '03100' => {sel: '', ja: '貧血', en: 'Anemia'},
    '03200' => {sel: '', ja: 'その他の血液及び造血器の疾患並びに免疫機構の障害', en: 'Other blood and hematopoietic organ diseases and immune system disorders'},
    '04000' => {sel: '', ja: '内分泌、栄養及び代謝疾患', en: 'Endocrine, nutritional, and metabolic diseases'},
    '04100' => {sel: '', ja: '糖尿病', en: 'Diabetes'},
    '04200' => {sel: '', ja: 'その他の内分泌、栄養及び代謝疾患', en: 'Other endocrine, nutritional, and metabolic diseases'},
    '05000' => {sel: '', ja: '精神及び行動の障害', en: 'Mental and behavioral disorders'},
    '05100' => {sel: '', ja: '血管性及び詳細不明の認知症', en: 'Vascular and unspecified dementia'},
    '05200' => {sel: '', ja: 'その他の精神及び行動の障害', en: 'Other mental and behavioral disorders'},
    #'06000' => {sel: '', ja: '神経系の疾患', en: 'Diseases of the nervous system'},
    '06000' => {sel: '', ja: 'アルツハイマー病やパーキンソン病など神経系の疾患', en: 'Alzheimer\'s, Parkinson\'s, and other nervous system diseases'},
    '06100' => {sel: '', ja: '髄膜炎', en: 'Meningitis'},
    '06200' => {sel: '', ja: '脊髄性筋萎縮症及び関連症候群', en: 'Spinal muscular atrophy and related syndromes'},
    '06300' => {sel: '', ja: 'パーキンソン病', en: 'Parkinson\'s disease'},
    '06400' => {sel: '', ja: 'アルツハイマー病', en: 'Alzheimer\'s disease'},
    '06500' => {sel: '', ja: 'その他の神経系の疾患', en: 'Other diseases of the nervous system'},
    '07000' => {sel: '', ja: '眼及び付属器の疾患', en: 'Diseases of the eye and adnexa'},
    '08000' => {sel: '', ja: '耳及び乳様突起の疾患', en: 'Diseases of the ear and mastoid process'},
    #'09000' => {sel: '', ja: '循環器系の疾患', en: 'Diseases of the circulatory system'},
    '09000' => {sel: '', ja: '心疾患や脳血管疾患など循環器系の疾患', en: 'Heart, cerebrovascular, and other cardiovascular diseases'},
    '09100' => {sel: '', ja: '高血圧性疾患', en: 'Hypertensive diseases'},
    '09101' => {sel: '', ja: '高血圧性心疾患及び心腎疾患', en: 'Hypertensive heart and kidney diseases'},
    '09102' => {sel: '', ja: 'その他の高血圧性疾患', en: 'Other hypertensive diseases'},
    '09200' => {sel: '', ja: '心疾患（高血圧性を除く）', en: 'Heart diseases (excl. hypertensive)'},
    '09201' => {sel: '', ja: '慢性リウマチ性心疾患', en: 'Chronic rheumatic heart diseases'},
    '09202' => {sel: '', ja: '急性心筋梗塞', en: 'Acute myocardial infarction'},
    '09203' => {sel: '', ja: 'その他の虚血性心疾患', en: 'Other ischemic heart diseases'},
    '09204' => {sel: '', ja: '慢性非リウマチ性心内膜疾患', en: 'Chronic nonrheumatic endocarditis'},
    '09205' => {sel: '', ja: '心筋症', en: 'Cardiomyopathy'},
    '09206' => {sel: '', ja: '不整脈及び伝導障害', en: 'Arrhythmias and conduction disorders'},
    '09207' => {sel: '', ja: '心不全', en: 'Heart failure'},
    '09208' => {sel: '', ja: 'その他の心疾患', en: 'Other heart diseases'},
    '09300' => {sel: '', ja: '脳血管疾患', en: 'Cerebrovascular diseases'},
    '09301' => {sel: '', ja: 'くも膜下出血', en: 'Subarachnoid hemorrhage'},
    '09302' => {sel: '', ja: '脳内出血', en: 'Intracerebral hemorrhage'},
    '09303' => {sel: '', ja: '脳梗塞', en: 'Cerebral infarction'},
    '09304' => {sel: '', ja: 'その他の脳血管疾患', en: 'Other cerebrovascular diseases'},
    '09400' => {sel: '', ja: '大動脈瘤及び解離', en: 'Aortic aneurysm and dissection'},
    '09500' => {sel: '', ja: 'その他の循環器系の疾患', en: 'Other diseases of the circulatory system'},
    '10000' => {sel: '', ja: '呼吸器系の疾患', en: 'Diseases of the respiratory system'},
    '10100' => {sel: '', ja: 'インフルエンザ', en: 'Influenza'},
    '10200' => {sel: '', ja: '肺炎', en: 'Pneumonia'},
    '10300' => {sel: '', ja: '急性気管支炎', en: 'Acute bronchitis'},
    '10400' => {sel: '', ja: '慢性閉塞性肺疾患', en: 'Chronic obstructive pulmonary disease'},
    '10500' => {sel: '', ja: '喘息', en: 'Asthma'},
    '10600' => {sel: '', ja: 'その他の呼吸器系の疾患', en: 'Other diseases of the respiratory system'},
    '10601' => {sel: '', ja: '誤嚥性肺炎', en: 'Aspiration pneumonia'},
    '10602' => {sel: '', ja: '間質性肺疾患', en: 'Interstitial lung disease'},
    '10603' => {sel: '', ja: 'その他の呼吸器系の疾患（10601及び10602を除く）', en: 'Other diseases of the respiratory system (excl. 10601 and 10602)'},
    '11000' => {sel: '', ja: '消化器系の疾患', en: 'Diseases of the digestive system'},
    '11100' => {sel: '', ja: '胃潰瘍及び十二指腸潰瘍', en: 'Gastric and duodenal ulcers'},
    '11200' => {sel: '', ja: 'ヘルニア及び腸閉塞', en: 'Hernia and intestinal obstruction'},
    '11300' => {sel: '', ja: '肝疾患', en: 'Liver diseases'},
    '11301' => {sel: '', ja: '肝硬変（アルコール性を除く）', en: 'Liver cirrhosis (excl. alcoholic)'},
    '11302' => {sel: '', ja: 'その他の肝疾患', en: 'Other liver diseases'},
    '11400' => {sel: '', ja: 'その他の消化器系の疾患', en: 'Other diseases of the digestive system'},
    '12000' => {sel: '', ja: '皮膚及び皮下組織の疾患', en: 'Diseases of the skin and subcutaneous tissue'},
    '13000' => {sel: '', ja: '筋骨格系及び結合組織の疾患', en: 'Diseases of the musculoskeletal system and connective tissue'},
    #'14000' => {sel: '', ja: '腎尿路生殖器系の疾患', en: 'Diseases of the genitourinary system'},
    '14000' => {sel: '', ja: '腎不全など腎尿路生殖器系の疾患', en: 'Renal failure and diseases of the genitourinary system'},
    '14100' => {sel: '', ja: '糸球体疾患及び腎尿細管間質性疾患', en: 'Glomerular diseases and tubulointerstitial diseases of the kidney'},
    '14200' => {sel: '', ja: '腎不全', en: 'Renal failure'},
    '14201' => {sel: '', ja: '急性腎不全', en: 'Acute renal failure'},
    '14202' => {sel: '', ja: '慢性腎臓病', en: 'Chronic kidney disease'},
    '14203' => {sel: '', ja: '詳細不明の腎不全', en: 'Renal failure of unspecified details'},
    '14300' => {sel: '', ja: 'その他の腎尿路生殖器系の疾患', en: 'Other diseases of the genitourinary system'},
    '15000' => {sel: '', ja: '妊娠、分娩及び産じょく', en: 'Pregnancy, childbirth, and the puerperium'},
    '16000' => {sel: '', ja: '周産期に発生した病態', en: 'Conditions originating in the perinatal period'},
    '16100' => {sel: '', ja: '妊娠期間及び胎児発育に関連する障害', en: 'Disorders related to the pregnancy period and fetal development'},
    '16200' => {sel: '', ja: '出産外傷', en: 'Obstetric trauma'},
    '16300' => {sel: '', ja: '周産期に特異的な呼吸障害及び心血管障害', en: 'Perinatal respiratory and cardiovascular disorders'},
    '16400' => {sel: '', ja: '周産期に特異的な感染症', en: 'Perinatal specific infections'},
    '16500' => {sel: '', ja: '胎児及び新生児の出血性障害及び血液障害', en: 'Hemorrhagic and hematological disorders of fetus and newborn'},
    '16600' => {sel: '', ja: 'その他の周産期に発生した病態', en: 'Other conditions originating in the perinatal period'},
    '17000' => {sel: '', ja: '先天奇形、変形及び染色体異常', en: 'Congenital malformations, deformations, and chromosomal abnormalities'},
    '17100' => {sel: '', ja: '神経系の先天奇形', en: 'Congenital malformations of the nervous system'},
    '17200' => {sel: '', ja: '循環器系の先天奇形', en: 'Congenital malformations of the circulatory system'},
    '17201' => {sel: '', ja: '心臓の先天奇形', en: 'Congenital malformations of the heart'},
    '17202' => {sel: '', ja: 'その他の循環器系の先天奇形', en: 'Other congenital malformations of the circulatory system'},
    '17300' => {sel: '', ja: '消化器系の先天奇形', en: 'Congenital malformations of the digestive system'},
    '17400' => {sel: '', ja: 'その他の先天奇形及び変形', en: 'Other congenital malformations and deformities'},
    '17500' => {sel: '', ja: '染色体異常、他に分類されないもの', en: 'Chromosomal abnormalities, not elsewhere classified'},
#    '18000' => {sel: '', ja: '症状、徴候及び異常臨床所見・異常検査所見で他に分類されないもの', en: 'Symptoms, signs, and abnormal clinical and laboratory findings, not elsewhere classified'},
    '18000' => {sel: '', ja: '老衰など症状・徴候が他に分類されないもの', en: 'Senility or symptoms not classified elsewhere'},
    '18100' => {sel: '', ja: '老衰', en: 'Senility'},
    '18200' => {sel: '', ja: '乳幼児突然死症候群(SIDS)', en: 'Sudden infant death syndrome (SIDS)'},
#    '18300' => {sel: '', ja: 'その他の症状、徴候及び異常臨床所見・異常検査所見で他に分類されないもの', en: 'Other symptoms, signs, and abnormal clinical and laboratory findings, not elsewhere classified'},
    '18300' => {sel: '', ja: '症状・徴候が他に分類されず', en: 'Symptoms not classified elsewhere'},
    #'20000' => {sel: '',  ja: '傷病及び死亡の外因', en: 'External causes of injuries, illnesses, and death' },
    '20000' => {sel: '',  ja: '不慮の事故や自殺など傷病及び死亡の外因', en: 'Accidents, suicide, and other external causes of injuries, illnesses, and death' },
    '20100' => {sel: '',  ja: '不慮の事故', en: 'Accidents' },
    '20101' => {sel: '',  ja: '交通事故', en: 'Traffic accidents' },
    '20102' => {sel: '',  ja: '転倒・転落・墜落', en: 'Falls' },
    '20103' => {sel: '',  ja: '不慮の溺死及び溺水', en: 'Accidental drowning and submersion' },
    '20104' => {sel: '',  ja: '不慮の窒息', en: 'Accidental suffocation' },
    '20105' => {sel: '',  ja: '煙、火及び火炎への曝露', en: 'Exposure to smoke, fire, and flames' },
    '20106' => {sel: '',  ja: '有害物質による不慮の中毒及び有害物質への曝露', en: 'Accidental poisoning and exposure to toxic substances' },
    '20107' => {sel: '',  ja: 'その他の不慮の事故', en: 'Other accidental injuries' },
    '20200' => {sel: '',  ja: '自殺', en: 'Suicide' },
    '20300' => {sel: '',  ja: '他殺', en: 'Homicide' },
    '20400' => {sel: '',  ja: 'その他の外因', en: 'Other external causes' },
    #'22000' => {sel: '',  ja: '特殊目的用コード', en: 'Codes for special purposes' },
    '22000' => {sel: '',  ja: '新型コロナ感染症など特殊目的用コード', en: 'COVID-19 and codes for special purposes' },
    '22100' => {sel: '',  ja: '重症急性呼吸器症候群[ＳＡＲＳ]', en: 'Severe acute respiratory syndrome (SARS)' },
    '22200' => {sel: '',  ja: '新型コロナ感染症', en: 'COVID-19' },
}

Death_codes.each do |k, v|
    v[:ja].sub!(/悪性新生物＜腫瘍＞/, '癌') # XXX
end

#
# カラム
#
Columns = {
    '1' => {sel: ''},
    '2' => {sel: ''},
    '3' => {sel: ''},
    '4' => {sel: ''},
    '5' => {sel: ''},
}

#
# グラフの種類
#
Graph_types = {
    'monthly' => {sel: '', ja: '月ごと', en: 'Monthly'},
    'yearly' => {sel: '', ja: '年ごと', en: 'Yearly'},
    'yearly_diff_2020' => {sel: '', ja: '2020年との差', en: 'Diffs compared to 2020'},
    'yearly_diff_2019' => {sel: '', ja: '2019年との差', en: 'Diffs compared to 2019'},
    'yearly_diff' => {sel: '', ja: '従来年との差', en: 'Diffs compared to prev years'},
    'yearly_ratio' => {sel: '', ja: '従来年との比率', en: 'Ratio compared to prev years'},
}

Regressions = {
    'none' => {sel: '', ja: '回帰線なし', en: 'No regression line'},
    '2019' => {sel: '', ja: '2019年までの回帰線', en: 'Regression through 2019'},
    '2020' => {sel: '', ja: '2020年までの回帰線', en: 'Regression through 2020'},
}


#
# 人口当り
#
Per_capita = {
    'true' => {sel: '', ja: '10万人あたり', en: 'Per capita 100,000'}
}

#
# 年齢調整方式
#
Adjustments = {
    'none' => {sel: '', ja: '年齢調整なし', en: 'No age adjustment'},
    'latest' => {sel: '', ja: '年齢調整（選択最終年月人口）',
                 en: 'Age adjustment (latest selected population)'},
    'standard2015' => {sel: '', ja: '年齢調整（2015年モデル人口）',
                       en: 'Age adjustment (2015 model population)'},
}

#
# TOP20
#
Top = {
    'none' => {sel: '', ja: 'しない', en: 'Disabled'},
    '20' => {sel: '', ja: '上位20', en: 'Top 20'},
    'dai10' => {sel: '', ja: '大分類上位10', en: 'Major-category top 10'},
    '-20' => {sel: '', ja: '減少上位20', en: 'Top 20 decrease'},
    'cancer20' => {sel: '', ja: '癌関連上位20', en: 'Cancer-related top 20'},
    'cancer10' => {sel: '', ja: '癌関連上位10', en: 'Cancer-related top 10'},
}

#
# 最大値を揃える
#
Align_max = {
    'true' => {sel: '', ja: '最大値を揃える(全死因以外)', en: 'Align maximum (excluding all causes)'}
}
Scale_modes = {
    'individual' => {sel: '', ja: '個別の表示範囲', en: 'Individual ranges'},
    'aligned' => {sel: '', ja: '最大値を揃える', en: 'Align maximum'},
    'aligned_except_all' => {sel: '', ja: '最大値を揃える(全死因以外)', en: 'Align maximum (excluding all causes)'},
    'expanded' => {sel: '', ja: '範囲拡大', en: 'Expanded ranges'}
}

#
# CGI.new
#
$cgi = CGI.new

DefaultParams = {
    'ages' => 'all~00_04~05_09~10_14~15_19~20_24~25_29~30_34~35_39~40_44~45_49~50_54~55_59~60_64~65_69~70_74~75_79~80_84~85_89~90_94~95_99~100over',
    'years' => '2021~2022~2023~2024~2025',
    'death_codes' => '04000~05000~06000~10000~11000~13000~14000~18000~20000~22000',
    'columns' => '3',
    'graph_type' => 'yearly_diff_2020',
    'top' => 'dai10',
}

# 旧URLは「年ごと」と独立した回帰線指定へ読み替える。
$legacy_regression = $cgi['graph_type'][/^yearly_reg_(2019|2020)$/, 1]

[
    {keys: 'ages', hash: Ages},
    {keys: 'years', hash: Years},
    {keys: 'death_codes', hash: Death_codes},
    {keys: 'columns', hash: Columns},
    {keys: 'graph_type', hash: Graph_types},
    {keys: 'align_max', hash: Align_max},
    {keys: 'per_capita', hash: Per_capita},
    {keys: 'top', hash: Top},
].each do |v|
    value = $cgi.has_key?(v[:keys]) ? $cgi[v[:keys]] : DefaultParams[v[:keys]]
    if value
        keys = value.split(/,|~|、/)
        if v[:keys] == 'years'
            keys = keys.flat_map{|key| key =~ /^(\d{4})-(\d{4})$/ ? ($1.to_i..$2.to_i).map(&:to_s) : key}
        elsif v[:keys] == 'ages'
            age_order = Ages.keys.reject{|key| key == 'all'}
            keys = keys.flat_map do |key|
                if key =~ /^(\d+)-(\d+|100over)$/
                    first = age_order.index{|age| age.sub(/^0/,'').to_i == $1.to_i}
                    last = $2 == '100over' ? age_order.index('100over') : age_order.index{|age| age.sub(/^0/,'').to_i == $2.to_i}
                    first && last ? age_order[first..last] : key
                else
                    key
                end
            end
        end
        keys.each do |key|
            if v[:hash][key]
                if v[:keys] =~ /^columns|^graph_type|^top/
                    v[:hash][key][:sel] = 'selected'
                    break
                end
                v[:hash][key][:sel] = 'checked'
            end
        end
    end
end

Top['none'][:sel] = 'selected' if ! Top.find{|key, value| value[:sel] == 'selected'}

if $legacy_regression
    Graph_types.each_value{|v| v[:sel] = ''}
    Graph_types['yearly'][:sel] = 'selected'
end

$regression = $legacy_regression ||
              ($cgi.has_key?('regression') ? $cgi['regression'] : '2020')
$regression = 'none' if ! Regressions[$regression]
Regressions[$regression][:sel] = 'selected'

$adjustment = $cgi['adjustment']
$adjustment = 'latest' if $adjustment == '' && $cgi['adjusted'] == 'true'
$adjustment = 'none' if ! Adjustments[$adjustment]
Adjustments[$adjustment][:sel] = 'checked'
$scale_mode = $cgi['scale'] || ($cgi['align_max'] == 'true' ? 'aligned_except_all' : 'individual')
$scale_mode = 'individual' unless Scale_modes.key?($scale_mode)
Scale_modes[$scale_mode][:sel] = 'selected'

$topflag = false
if Top.find{|k, v| v[:sel] == 'selected'} && Top['none'][:sel] != 'selected'
    $topflag = true
end

# 年ごとの検索系では、既存の死因選択順を検索結果に混ぜない。
# 「全死因」だけは、選択されていたかどうかを維持する。
if $topflag && Graph_types.find{|key, value| value[:sel] == 'selected'}&.first == 'yearly'
    all_selected = Death_codes['all'][:sel] == 'checked'
    Death_codes.each{|key, value| value[:sel] = (key == 'all' && all_selected) ? 'checked' : ''}
end

#
# Language
#
lang = $cgi['l']
$echeck = ''
$jcheck = ''
$init_locs = ''
if (lang =~ /^(en|english)/i) ||
   (lang == '' && ENV['HTTP_ACCEPT_LANGUAGE'] !~ /^ja/)
    $l    = :en
    $echeck = 'checked'
else
    $l    = :ja
    $jcheck = 'checked'
end

$title = {ja: '日本の死因別死者数', en: 'Deaths by Cause in Japan'}[$l]

#
# Height
#
$height = ($cgi['height'] != '' && $cgi['height'].to_i >= 50) ? $cgi['height'].to_i : 150

#
# Width
#
$width = ($cgi['width'] != '') ? $cgi['width'] : '100%'

#
# Step
#
$step = ($cgi['step'] != '') ? $cgi['step'] : '18'

#
# iFrame
#
$iframeflag = $cgi.has_key?('i') ? $cgi['i'] : $cgi['iframe']
if $iframeflag == '1' || $iframeflag == 'true'
    $iframeflag = true
else
    $iframeflag = false
end

#
# 男女
#
$bcheck = ''
$mcheck = ''
$fcheck = ''
$append = '('

$sex = $cgi['sex']
if $sex =~ /^f/
    $sex = 'female'
    $fcheck = 'checked'
    $append += {ja: '女性、', en: 'Female, '}[$l]
elsif $sex =~ /^m/
    $sex = 'male'
    $mcheck = 'checked'
    $append = {ja: '男性、', en: 'Male, '}[$l]
else
    $sex = 'both'
    $bcheck = 'checked'
end

#
# 年齢選択
#
if ! Ages.find{|k, v| v[:sel] == 'checked'}
    Ages['all'][:sel] = 'checked'
end

if Ages['all'][:sel] == 'checked'
    Ages.each do |k, v|
        v[:sel] = StandardAgeKeys.include?(k) || k == 'all' ? 'checked' : ''
    end
elsif Ages['elementary'][:sel] == 'checked' || Ages['junior'][:sel] == 'checked'
    Ages.each do |k, v|
        next if k =~ /^elementary|^junior/
        v[:sel] = ''
    end
end

if $adjustment == 'standard2015' &&
   (Ages['95_99'][:sel] == 'checked' || Ages['100over'][:sel] == 'checked')
    Ages['95_99'][:sel] = 'checked'
    Ages['100over'][:sel] = 'checked'
end

$all_ages_selected = Ages['all'][:sel] == 'checked'
$ages = if $all_ages_selected
            Ages.select{|k, v| StandardAgeKeys.include?(k)}
        else
            Ages.select{|k, v| v[:sel] == 'checked'}
        end
$includes_all_oldest = OldestAgeKeys.all?{|age| $ages.key?(age)}

agestr = {ja: '', en: 'Age '}[$l]
ages_for_description = $all_ages_selected ? {'all' => Ages['all']} : $ages
ages_for_description.each do |age, v|
    if age == 'all'
        agestr += {ja: '全年齢、', en: 'All age, '}[$l]
        break
    end
    next if age == '100over'
    if (agestr.slice(-3..-2).to_i + 1) == age.slice(0..1).to_i
        agestr = agestr.slice(0..-5) + '-' + age.slice(-2..-1) + ','
    elsif age == 'elementary' || age == 'junior'
        agestr += "#{Ages[age][:ja]}、"
    else
        agestr += "#{age.gsub('_','-')},"
    end
end
if agestr !~ /齢、$/
    if Ages['100over'][:sel] == 'checked'
        if agestr =~ /99/
            agestr = agestr.slice(0..-5) + {ja: '歳以上、', en: 'over, '}[$l]
        else
            agestr += Ages['100over'][$l] + {ja: '、', en: ', '}[$l]
        end
    else
        agestr.gsub!(/,$/, {ja: '歳、', en: 'yo, '}[$l])
    end
end
agestr.sub!(/00歳以上/, '全年齢')
$append += agestr

if Years.select{|k, v| v[:sel] == 'checked'} == {}
    (2019..2025).each do |year|
        Years["#{year}"][:sel] = 'checked'
    end
end

#
# Years_ref
#
if ! Graph_types.find{|k, v| v[:sel] == 'selected'}
    Graph_types['monthly'][:sel] = 'selected'
end

$years = Years.select{|k, v| v[:sel] == 'checked'}.map{|k, v| k}
$last_year = $years.max{|a, b| a.to_i <=> b.to_i}

$years_ref = Array.new
if Graph_types['yearly_diff_2019'][:sel] == 'selected'
    $years_ref.unshift('2019')
elsif Graph_types['yearly_diff_2020'][:sel] == 'selected'
    $years_ref.unshift('2020')
elsif Graph_types['yearly_ratio'][:sel] == 'selected' ||
   Graph_types['yearly_diff'][:sel] == 'selected' || $topflag
    min = $years.min{|a, b| a.to_i <=> b.to_i}.to_i
    ((min-5)..(min-1)).reverse_each do |year|
        break if year < 2014 || ! Years[year.to_s]
        $years_ref.unshift(year.to_s)
    end
end

($graph_key, _) = Graph_types.find{|k, v| v[:sel] == 'selected'}
$selected_graph_type = $graph_key
$years_context = case $selected_graph_type
                 when 'yearly_diff_2019'
                     (2014..2019).map(&:to_s)
                 when 'yearly_diff_2020'
                     (2015..2020).map(&:to_s)
                 when 'yearly_diff'
                     $years_ref.dup
                 else
                     []
                 end
$show_yearly_overview = $topflag && $selected_graph_type =~ /^yearly_diff/
$graph_key = 'yearly_diff' if $graph_key =~ /^yearly_diff/
if $graph_key =~ /yearly_ratio/
    if $years_ref.count == 1
        $append += {ja: "#{$years_ref[0]}との比較、", en: "compared to #{$years_ref[0]}, "}[$l]
    else
        $append += {ja: "#{$years_ref[0]}〜#{$years_ref[-1]}平均との比較、",
                    en: "compared to #{$years_ref[0]}-#{$years_ref[-1]} average, "}[$l]
    end
elsif $graph_key =~ /yearly_diff/
    if $years_ref.count == 1
        $append += {ja: "#{$years_ref[0]}との差、", en: "compared to #{$years_ref[0]}, "}[$l]
    else
        $append += {ja: "#{$years_ref[0]}〜#{$years_ref[-1]}平均との差、",
                    en: "compared to #{$years_ref[0]}-#{$years_ref[-1]} average, "}[$l]
    end
else
    $append += Graph_types[$graph_key][$l] + {ja: '、', en: ', '}[$l]
end
[Per_capita, Top].each do |hash|
    hash.each do |k, v|
        next if k == 'none'
        $append +=  v[$l] + {ja: '、', en: ', '}[$l] if v[:sel] != ''
    end
end
$append += Adjustments[$adjustment][$l] + {ja: '、', en: ', '}[$l] if $adjustment != 'none'

$append = $append.sub(/,\s*$|、\s*$/,'') + ')'

#
# カラム数
#
if ! Columns.find{|k, v| v[:sel] == 'selected'}
    Columns['3'][:sel] = 'selected'
end
$columns = Columns.find{|k, v| v[:sel] == 'selected'}[0].to_i
if !$cgi.has_key?('columns') && ENV['HTTP_USER_AGENT'].to_s =~ /iPhone|iPad|Android/i
    $columns = 2
    Columns.each{|k, v| v[:sel] = (k == '2' ? 'selected' : '')}
end

#
# グラフ形式
#
if ! Graph_types.find{|k, v| v[:sel] == 'selected'}
    Graph_types['monthly'][:sel] = 'selected'
end

if ! $topflag && Death_codes.select{|k, v| v[:sel] == 'checked'} == {}
    ['all', '10000', '10100', '18000', '20102', '22200'].each do |k|
        Death_codes[k][:sel] = 'checked'
    end
end

# 年の連続範囲をURL用の短い表記へ圧縮する。
# Compress consecutive years into the compact URL representation.
def compact_years(values)
    values = values.map(&:to_i).sort.uniq
    out = []
    i = 0
    while i < values.length
        j = i
        j += 1 while j + 1 < values.length && values[j + 1] == values[j] + 1
        out << (j - i >= 1 ? "#{values[i]}-#{values[j]}" : values[i].to_s)
        i = j + 1
    end
    out.join('~')
end

# 年齢の連続範囲をURL用の短い表記へ圧縮する。
# Compress consecutive ages into the compact URL representation.
def compact_ages(values)
    return 'all' if values.include?('all')
    order = Ages.keys.reject{|v| v == 'all'}
    indexes = values.map{|v| order.index(v)}.compact.sort.uniq
    out = []
    i = 0
    while i < indexes.length
        j = i
        j += 1 while j + 1 < indexes.length && indexes[j + 1] == indexes[j] + 1
        a = order[indexes[i]].sub(/^0+/, '').sub('_', '-')
        b = order[indexes[j]].sub(/^0+/, '').sub('_', '-')
        out << (j - i >= 1 ? "#{a}-#{b.sub(/^\d+$/, '&') }" : a)
        i = j + 1
    end
    out.join('~')
end

canonical_params = [
    ['l', $l.to_s],
    ['years', compact_years($years)],
    ['ages', compact_ages(Ages.select{|key, value| value[:sel] == 'checked'}.keys)],
    ['sex', $sex],
    ['graph_type', Graph_types.find{|key, value| value[:sel] == 'selected'}[0]],
    ['top', Top.find{|key, value| value[:sel] == 'selected'}[0]],
    ['columns', $columns.to_s],
    ['death_codes', Death_codes.select{|key, value| value[:sel] == 'checked'}.keys.join('~')],
    ['scale', $scale_mode],
    ['per_capita', Per_capita['true'][:sel] == 'checked' ? 'true' : ''],
    ['adjustment', $adjustment],
    ['regression', $regression],
    ['i', $iframeflag ? 'true' : 'false'],
]
%w[height width step].each do |key|
    canonical_params.push([key, $cgi[key]]) if $cgi.has_key?(key)
end
canonical_query = '?' + URI.encode_www_form(canonical_params)

#
# 呼吸器系疾患に新型コロナを含めるか
#
$c19addflag = ''
if $cgi['c19add'] == 'true' || $cgi['c19add'] == 1
    $c19addflag = 'checked'
end

print_header(:title => $title, :iframe => $iframeflag)
print "<script>history.replaceState(null, '', window.location.pathname + #{JSON.generate(canonical_query)});</script>\n"

if ! $iframeflag
    print <<EOF
  <p class=l>
  <style>
    .range-selector { display: flex; align-items: center; gap: .8em; margin: .35em 0; }
    .range-selector-label { min-width: 3em; }
    .range-panel { display: flex; align-items: center; gap: .7em; flex: 1; }
    [hidden] { display: none !important; }
    .dual-range { position: relative; min-width: 18em; max-width: 42em; height: 2.8em; flex: 1; }
    .dual-range::before {
      content: ""; position: absolute; left: 0; right: 0; top: .72em; height: .28em;
      border-radius: .2em;
      background: linear-gradient(to right,
        #bbb 0%, #bbb var(--low), #0676e8 var(--low), #0676e8 var(--high),
        #bbb var(--high), #bbb 100%);
    }
    .dual-range input[type="range"] {
      -webkit-appearance: none; appearance: none;
      position: absolute; left: 0; top: .15em; width: 100%; height: 1.4em;
      margin: 0; pointer-events: none; background: transparent;
    }
    .dual-range input[type="range"]::-webkit-slider-runnable-track { height: .28em; background: transparent; }
    .dual-range input[type="range"]::-moz-range-track { height: .28em; background: transparent; }
    .dual-range input[type="range"]::-webkit-slider-thumb {
      -webkit-appearance: none; appearance: none; pointer-events: auto;
      width: 1.2em; height: 1.2em; margin-top: -.46em;
      border: 2px solid white; border-radius: 50%; background: #666;
      box-shadow: 0 0 2px #333;
    }
    .dual-range input[type="range"]::-moz-range-thumb {
      pointer-events: auto; width: 1.2em; height: 1.2em;
      border: 2px solid white; border-radius: 50%; background: #666;
      box-shadow: 0 0 2px #333;
    }
    .range-ticks { position: absolute; left: 0; right: 0; top: 1.55em; height: 1.1em; }
    .range-tick { position: absolute; transform: translateX(-50%); font-size: .72em; color: #555; }
    .range-tick::before {
      content: ""; position: absolute; left: 50%; top: -.32em;
      width: 1px; height: .28em; background: #888;
    }
    .range-value { min-width: 12em; text-align: center; }
    .selector-switch { white-space: nowrap; }
    .checkbox-panel { line-height: 1.8; }
    .disclosure-summary {
      width: fit-content; cursor: pointer;
    }
    .disclosure-action {
      display: inline-block; padding: .1em .4em;
      border: 1px solid #888; border-radius: .25em; background: #f5f5f5;
    }
  </style>
  <script>
    const rubyDomainStrings = {};
    const rubyExpandedDomains = {};
  const standardAgeValues = #{JSON.generate(StandardAgeKeys)};
  const standardAgeLabels = #{JSON.generate(StandardAgeKeys.map{|age| Ages[age][$l]})};
  const yearValues = #{JSON.generate(Years.keys)};
  const currentLanguage = #{JSON.generate($l.to_s)};

  function selectorValues(kind) {
    return kind == 'age' ? standardAgeValues : yearValues;
  }

  function selectorLabels(kind) {
    return kind == 'age' ? standardAgeLabels : yearValues;
  }

  function compactAgeValue(index) {
    var value = standardAgeValues[index];
    return {number: value == '100over' ? 100 : Number(value.slice(0, 2)),
            over: value == '100over'};
  }

  function selectorCheckboxes(kind) {
    var name = kind == 'age' ? 'age' : 'year';
    return Array.from(document.querySelectorAll(`input[name="${name}"]`));
  }

  function rangeSelectionIsContiguous(kind) {
    var values = selectorValues(kind);
    var checked = selectorCheckboxes(kind).filter(checkbox => checkbox.checked);
    if (kind == 'age' && checked.some(checkbox =>
        !values.includes(checkbox.value) && checkbox.value != 'all')) return false;
    var indexes = checked.map(checkbox => values.indexOf(checkbox.value)).filter(index => index >= 0);
    if (indexes.length == 0) return false;
    var min = Math.min(...indexes);
    var max = Math.max(...indexes);
    return indexes.length == max - min + 1;
  }

  function updateRangeLabel(kind) {
    var labels = selectorLabels(kind);
    var min = Number(document.getElementById(`${kind}-range-min`).value);
    var max = Number(document.getElementById(`${kind}-range-max`).value);
    var text;
    if (kind == 'age') {
      if (min == 0 && compactAgeValue(max).over) {
        text = currentLanguage == 'ja' ? '全年齢' : 'All ages';
      } else if (min == max) {
        text = labels[min];
      } else {
        var first = compactAgeValue(min);
        var last = compactAgeValue(max);
        text = currentLanguage == 'ja'
          ? (last.over ? `${first.number}歳以上` : `${first.number}–${last.number}歳`)
          : (last.over ? `${first.number}+` : `${first.number}–${last.number}yo`);
      }
    } else {
      text = currentLanguage == 'ja' ? `${labels[min]}–${labels[max]}年` : `${labels[min]}–${labels[max]}`;
    }
    document.getElementById(`${kind}-range-value`).textContent = text;
    var denominator = labels.length - 1;
    var range = document.getElementById(`${kind}-range-min`).parentElement;
    range.style.setProperty('--low', `${min * 100 / denominator}%`);
    range.style.setProperty('--high', `${max * 100 / denominator}%`);
  }

  function syncRangeFromCheckboxes(kind) {
    var values = selectorValues(kind);
    var indexes = selectorCheckboxes(kind).
      filter(checkbox => checkbox.checked).
      map(checkbox => values.indexOf(checkbox.value)).
      filter(index => index >= 0);
    if (indexes.length == 0) return;
    document.getElementById(`${kind}-range-min`).value = Math.min(...indexes);
    document.getElementById(`${kind}-range-max`).value = Math.max(...indexes);
    updateRangeLabel(kind);
  }

  function updateCheckboxesFromRange(kind, changed) {
    var minInput = document.getElementById(`${kind}-range-min`);
    var maxInput = document.getElementById(`${kind}-range-max`);
    if (Number(minInput.value) > Number(maxInput.value)) {
      if (changed == 'min') maxInput.value = minInput.value;
      else minInput.value = maxInput.value;
    }
    var min = Number(minInput.value);
    var max = Number(maxInput.value);
    var values = selectorValues(kind);
    selectorCheckboxes(kind).forEach(checkbox => {
      var index = values.indexOf(checkbox.value);
      if (index >= 0) checkbox.checked = index >= min && index <= max;
      else if (kind == 'age') checkbox.checked = false;
    });
    if (kind == 'age') syncAllAges();
    updateRangeLabel(kind);
  }

  function showSelectorMode(kind, mode) {
    document.getElementById(`${kind}-slider-panel`).hidden = mode != 'slider';
    document.getElementById(`${kind}-checkbox-panel`).hidden = mode != 'checkbox';
    if (mode == 'slider') {
      syncRangeFromCheckboxes(kind);
      updateCheckboxesFromRange(kind, 'min');
    }
  }

  function initializeRangeSelector(kind) {
    var values = selectorValues(kind);
    ['min', 'max'].forEach(edge => {
      var input = document.getElementById(`${kind}-range-${edge}`);
      input.max = values.length - 1;
    });
    var ticks = document.getElementById(`${kind}-range-ticks`);
    values.forEach((value, index) => {
      var show = kind == 'age' ? index % 2 == 0 : Number(value) % 5 == 0;
      if (!show) return;
      var tick = document.createElement('span');
      tick.className = 'range-tick';
      tick.style.left = `${index * 100 / (values.length - 1)}%`;
      tick.textContent = kind == 'age' ?
        (value == '100over' ? 100 : Number(value.slice(0, 2))) : value;
      ticks.appendChild(tick);
    });
    syncRangeFromCheckboxes(kind);
    showSelectorMode(kind, rangeSelectionIsContiguous(kind) ? 'slider' : 'checkbox');
  }

  function toggleAllAges(checked) {
    document.querySelectorAll('input[name="age"]').forEach(checkbox => {
      if (checkbox.value == 'all' || standardAgeValues.includes(checkbox.value)) {
        checkbox.checked = checked;
      }
    });
    syncRangeFromCheckboxes('age');
  }

  function syncAllAges() {
    document.querySelector('input[name="age"][value="all"]').checked =
      standardAgeValues.every(value =>
        document.querySelector(`input[name="age"][value="${value}"]`).checked
      );
  }

  function clearDeathCodes() {
    document.querySelectorAll('input[name="death_code"]').forEach(checkbox => {
      checkbox.checked = false;
    });
    updateDeathCodeSummary();
  }

  function updateDeathCodeSummary() {
    var summary = document.getElementById('death-code-summary');
    if (!summary) return;
    var checked = Array.from(document.querySelectorAll('input[name="death_code"]:checked'));
    if (checked.some(checkbox => checkbox.dataset.searchRank)) {
      checked.sort((a, b) =>
        Number(a.dataset.searchRank || Number.MAX_SAFE_INTEGER) -
        Number(b.dataset.searchRank || Number.MAX_SAFE_INTEGER)
      );
    }
    var labels = checked.map(checkbox =>
      checkbox.parentElement.textContent.trim().replace(/^[0-9]{5}:[ ]*/, '')
    );
    var shown = [];
    var length = 0;
    var truncated = false;
    labels.forEach(label => {
      var addition = (shown.length ? '、' : '') + label;
      if (length + addition.length > 50) truncated = true;
      else {
        shown.push(label);
        length += addition.length;
      }
    });
    var selected = shown.join('、');
    if (truncated) selected += '……など';
    if (!selected) selected = currentLanguage == 'ja' ? 'なし' : 'None';
    var opened = document.getElementById('death-code-details').open;
    var action = document.createElement('span');
    action.className = 'disclosure-action';
    action.textContent = currentLanguage == 'ja'
      ? (opened ? '閉じる' : '開く')
      : (opened ? 'Close' : 'Open');
    if (currentLanguage == 'ja') {
      summary.replaceChildren(
        document.createTextNode('死因チェックボックスを'), action,
        document.createTextNode(` (選択中: ${selected})`)
      );
    } else {
      summary.replaceChildren(
        action, document.createTextNode(` cause checkboxes (selected: ${selected})`)
      );
    }
  }

  function ensureStandard2015OldestAges() {
    var adjustment = document.querySelector('select[name="adjustment"]').value;
    var age95 = document.querySelector('input[name="age"][value="95_99"]');
    var age100 = document.querySelector('input[name="age"][value="100over"]');
    if (adjustment == 'standard2015' && age95.checked != age100.checked) {
      age95.checked = true;
      age100.checked = true;
      syncAllAges();
      syncRangeFromCheckboxes('age');
      var language = document.querySelector('input[name="l"]:checked').value;
      alert(language == 'ja'
        ? '2015年モデル人口では95歳以上が一つの年齢階級なので、95–99歳と100歳以上の両方を選択します。'
        : 'The 2015 model population uses one 95-and-over group, so both ages 95–99 and 100+ will be selected.');
    }
  }

  function buildQueryString() {
    ensureStandard2015OldestAges();
    var l = document.querySelector('input[name="l"]:checked').value;
    var years = Array.from(document.querySelectorAll('input[name="year"]:checked'),
                           checkbox => checkbox.value);
    var ages = Array.from(document.querySelectorAll('input[name="age"]:checked'),
                          checkbox => checkbox.value);
    var sex = Array.from(document.querySelectorAll('input[name="sex"]:checked'),
                         checkbox => checkbox.value);
    var graph_type = Array.from(document.querySelectorAll('select[name="graph_type"] option:checked'),
                                option => option.value);
    var top = Array.from(document.querySelectorAll('select[name="top"] option:checked'),
                                option => option.value);
    var columns = Array.from(document.querySelectorAll('select[name="columns"] option:checked'),
                                option => option.value);
    var death_codes= Array.from(document.querySelectorAll('input[name="death_code"]:checked'),
                                checkbox => checkbox.value);
    var scale = document.querySelector('select[name="scale"]').value;
    var per_capita = Array.from(document.querySelectorAll('input[name="per_capita"]:checked'),
                               checkbox => checkbox.value);
    var adjustment = document.querySelector('select[name="adjustment"]').value;
    var regression = document.querySelector('select[name="regression"]').value;

    function compactRange(values, ageMode) {
      if (ageMode && values.includes('all')) return 'all';
      const order = ageMode ? ['00_04','05_09','10_14','15_19','20_24','25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64','65_69','70_74','75_79','80_84','85_89','90_94','95_99','100over'] : null;
      const nums = ageMode ? values.map(v => order.indexOf(v)).filter(v => v >= 0).sort((a,b) => a-b) : values.map(Number).sort((a,b) => a-b);
      const out = [];
      for (let i=0; i<nums.length; i++) {
        let j=i; while (j+1<nums.length && nums[j+1]===nums[j]+1) j++;
        const a = ageMode ? order[nums[i]].replace(/^0/,'').replace('_','-') : String(nums[i]);
        const b = ageMode ? order[nums[j]].replace(/^0/,'').replace('_','-') : String(nums[j]);
        out.push(j-i >= 1 ? a + '-' + b : a);
        i=j;
      }
      return out.join('~');
    }
    return window.location.pathname + '?l=' + l
        + '&years=' + compactRange(years, false)
        + '&ages=' + compactRange(ages, true)
        + '&sex=' + sex
        + '&graph_type=' + graph_type
        + '&top=' + top
        + '&columns=' + columns
        + '&death_codes=' + death_codes.join('~')
        + '&scale=' + scale
        + '&per_capita=' + per_capita
        + '&adjustment=' + adjustment
        + '&regression=' + regression
        + '&i=#{$iframeflag}'
    ;
  }

  function submitForm() {
    window.location.href = buildQueryString();
  }

  document.addEventListener('DOMContentLoaded', () => {
    initializeRangeSelector('age');
    initializeRangeSelector('year');
    document.querySelectorAll(
      'select[name="scale"], select[name="columns"]'
    ).forEach(input => {
      input.addEventListener('change', () => {
        if (window.renderInstantSelection) window.renderInstantSelection();
      });
    });
    document.querySelectorAll('input[name="death_code"]').forEach(input => {
      input.addEventListener('change', updateDeathCodeSummary);
    });
    document.getElementById('regression-select').addEventListener('change', input => {
      var url = new URL(window.location.href);
      url.searchParams.set('regression', input.target.value);
      history.replaceState(null, '', url);
    });
    document.getElementById('death-code-details').addEventListener('toggle', updateDeathCodeSummary);
    updateDeathCodeSummary();
    document.querySelector('select[name="graph_type"]').addEventListener('change', updateRegressionVisibility);
    updateRegressionVisibility();
  });

  function updateRegressionVisibility() {
    var control = document.getElementById('regression-control');
    if (control) control.hidden = !#{$show_yearly_overview ? 'true' : 'false'} &&
      document.querySelector('select[name="graph_type"]').value != 'yearly';
  }
  </script>
  <form id="myForm" onsubmit="submitForm(); return false;" style="text-align: left;">
    <div class="range-selector">
      <span class="range-selector-label">#{{ja:'年齢', en:'Age'}[$l]}</span>
      <div id="age-slider-panel" class="range-panel">
        <div class="dual-range">
          <input id="age-range-min" type="range" min="0" value="0"
                 oninput="updateCheckboxesFromRange('age', 'min')">
          <input id="age-range-max" type="range" min="0" value="0"
                 oninput="updateCheckboxesFromRange('age', 'max')">
          <div id="age-range-ticks" class="range-ticks"></div>
        </div>
        <span id="age-range-value" class="range-value"></span>
        <button type="button" class="selector-switch"
                onclick="showSelectorMode('age', 'checkbox')">#{ {ja:'チェックボックスに切替え', en:'Switch to checkboxes'}[$l] }</button>
      </div>
      <div id="age-checkbox-panel" class="checkbox-panel" hidden>
EOF
    Ages.each do |k, v|
        onchange = if k == 'all'
                       'onchange="toggleAllAges(this.checked)"'
                   elsif StandardAgeKeys.include?(k)
                       'onchange="syncAllAges()"'
                   else
                       ''
                   end
        print <<EOF
    <span><input type="checkbox" name="age" value="#{k}" #{v[:sel]} #{onchange}> #{v[$l]}</span>
EOF
    end
print <<EOF
        <button type="button" class="selector-switch"
                onclick="showSelectorMode('age', 'slider')">#{ {ja:'スライダーに切替え', en:'Switch to sliders'}[$l] }</button>
      </div>
    </div>
    <span>
      <input type="radio" name="sex" value="both" #{$bcheck}>#{{ja:'男女',en:'Both'}[$l]}
      <input type="radio" name="sex" value="male" #{$mcheck}>#{{ja:'男性',en:'Male'}[$l]}
      <input type="radio" name="sex" value="female" #{$fcheck}>#{{ja:'女性',en:'Female'}[$l]}
    </span>
    <div class="range-selector">
      <span class="range-selector-label">#{{ja:'年', en:'Year'}[$l]}</span>
      <div id="year-slider-panel" class="range-panel">
        <div class="dual-range">
          <input id="year-range-min" type="range" min="0" value="0"
                 oninput="updateCheckboxesFromRange('year', 'min')">
          <input id="year-range-max" type="range" min="0" value="0"
                 oninput="updateCheckboxesFromRange('year', 'max')">
          <div id="year-range-ticks" class="range-ticks"></div>
        </div>
        <span id="year-range-value" class="range-value"></span>
        <button type="button" class="selector-switch"
                onclick="showSelectorMode('year', 'checkbox')">#{ {ja:'チェックボックスに切替え', en:'Switch to checkboxes'}[$l] }</button>
      </div>
      <div id="year-checkbox-panel" class="checkbox-panel" hidden>
EOF
    Years.each do |k, v|
        print <<EOF
    <span><input type="checkbox" name="year" value="#{k}" #{v[:sel]}> #{k}</span>
EOF
    end
print <<EOF
        <button type="button" class="selector-switch"
                onclick="showSelectorMode('year', 'slider')">#{ {ja:'スライダーに切替え', en:'Switch to sliders'}[$l] }</button>
      </div>
    </div>
    <details id="death-code-details"><summary id="death-code-summary" class="disclosure-summary">#{{ja: '死因チェックボックスを', en: ''}[$l]}<span class="disclosure-action">#{{ja:'開く', en:'Open'}[$l]}</span>#{{ja:'', en:' cause checkboxes'}[$l]}</summary>
      <button type="button" onclick="clearDeathCodes()">#{{ja:'死因選択をクリア', en:'Clear causes'}[$l]}</button>
      <details>
        <summary><span><input type="checkbox" name="death_code" value="all" #{Death_codes['all'][:sel]}> #{{ja: '全死因', en: 'All cause'}[$l]}</span></summary>
        <ul style="list-style-type: none;">
EOF
    Death_codes.each do |k, v|
        next if k =~ /all/
        if k =~ /000$/
            print <<EOF
        </ul>
      </details>
      <details open>
        <summary><span><input type="checkbox" name="death_code" value="#{k}" #{v[:sel]}> #{k}: #{v[$l]} <!-- (#{{ja: 'クリックして更に展開', en: 'Expand more by clicking'}[$l]}) --> </span></summary>
        <ul style="list-style-type: none;">
EOF
        else
            print <<EOF
          <li> <span><input type="checkbox" name="death_code" value="#{k}" #{v[:sel]}> #{k}: #{v[$l]}</span>
EOF
        end
    end
    print <<EOF
        </ul>
      </details>
    </details>
    <span>
      #{{ja:'グラフ形式', en:'Graph Types'}[$l]}
      <select name="graph_type">
EOF
    Graph_types.each do |k, v|
        print <<EOF
        <option value="#{k}" #{v[:sel]}>#{v[$l]}</option>
EOF
    end
    print <<EOF
      </select>
    </span>
    <span>
      #{{ja:'死因検索', en:'Cause search'}[$l]}
      <select name="top">
EOF
    Top.each do |k, v|
        print <<EOF
        <option value="#{k}" #{v[:sel]}>#{v[$l]}</option>
EOF
    end
    print <<EOF
      </select>
    </span>
    <span>
      <select name="adjustment">
EOF
    Adjustments.each do |k, v|
        print <<EOF
        <option value="#{k}" #{v[:sel] == 'checked' ? 'selected' : ''}>#{v[$l]}</option>
EOF
    end
    print <<EOF
      </select>
    </span>
    <span>
      <label><input type="checkbox" name="per_capita" value="true" #{Per_capita['true'][:sel]}>
      #{Per_capita['true'][$l]}</label>
    </span>
    <span>
      <input type="radio" name="l" value="ja" #{$jcheck}>日本語
      <input type="radio" name="l" value="en" #{$echeck}>English
    </span>
    <input type="submit" value="送信/Submit">
    <div id="instant-controls" style="margin-top: .35em;">
      <span>#{{ja:'表示設定', en:'Display settings'}[$l]}:</span>
    <span id="regression-control">
      <select id="regression-select" name="regression">
EOF
    Regressions.each do |k, v|
        print <<EOF
        <option value="#{k}" #{v[:sel]}>#{v[$l]}</option>
EOF
    end
    print <<EOF
      </select>
    </span>
    <span>
      #{{ja:'カラム数', en:'Columns'}[$l]}
      <select name="columns">
EOF
    Columns.each do |k, v|
        print <<EOF
        <option value="#{k}" #{v[:sel]}>#{k}</option>
EOF
    end
    print <<EOF
      </select>
    </span>
    <span>
      <select name="scale">
        <option value="individual" #{Scale_modes['individual'][:sel]}>#{Scale_modes['individual'][$l]}</option>
        <option value="aligned" #{Scale_modes['aligned'][:sel]}>#{Scale_modes['aligned'][$l]}</option>
        <option value="aligned_except_all" #{Scale_modes['aligned_except_all'][:sel]}>#{Scale_modes['aligned_except_all'][$l]}</option>
        <option value="expanded" #{Scale_modes['expanded'][:sel]}>#{Scale_modes['expanded'][$l]}</option>
      </select>
    </span>
    </div>
  </form>
EOF
end

print <<EOF
  <h3 id="result-title" style="text-align: center;">#{$title} #{$append}</h3>
  <div id="vis" style="width: #{$width};">
  <span id="blink1223" style="font-size: large; font-weight: bold;">#{{ja: '読込中...', en: 'Now Loading...'}[$l]}</span><script>with(blink1223)id='',style.opacity=1,setInterval(function(){style.opacity^=1},500)</script>
  </div>
#{if $show_yearly_overview
    <<~HTML
      <h3 id="yearly-overview-title" style="text-align: center;">#{{ja:'検索された死因の年ごと表示', en:'Yearly view of searched causes'}[$l]}</h3>
      <div id="vis-yearly" style="width: #{$width};"></div>
    HTML
  else
    ''
  end}
EOF
$stdout.flush
print <<EOF
  <script>
    const spec = {
      "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
      "config": {
        "mark": {"clip": true},
        "title": {"fontSize": 15},
        "axis": {"titleFontSize": 14, "labelFontSize": 14},
        "legend": {"titleFontSize": 14, "labelFontSize": 14, "labelLimit": 0}
      },
      "params": [{
        "name": "regressionChoice",
        "value": #{JSON.generate($regression)},
        "bind": {"element": "#regression-select", "event": "change"}
      }],
      "data": {
        "name": "stats",
EOF
    print '        "values": '

# 選択した死因の月次Vega-Liteグラフ定義を出力する。
# Render monthly Vega-Lite chart specifications for the selected causes of death.
def print_monthly(death_codes)

    print <<EOF
      },
      "columns": #{$columns},
      "concat": [
EOF

    $firstflag = true
    death_codes.each do |code|
        if code =~ /population/
            cause = {sel: 'checked', ja: '人口', en: 'Population'}
        else
            cause = Death_codes[code]
        end
        next if ! cause[:sel] && ! $topflag
        domain_str = $scale_mode == 'expanded' ? ($expanded_domains[code] || '"domain": "unaggregated"') : ((code == 'all' && $scale_mode == 'aligned_except_all') ? '"domain": "unaggregated"' : $domain_str[$scale_mode])
        if $firstflag
            $firstflag = false
        else
            puts '        ,'
        end
        title = {ja: cause[$l].slice(0..25), en: cause[$l].slice(0..49)}[$l]
        print <<EOF
        {
          "height": #{$height},
          "title": [ "#{title}" ],
          "encoding": {
            "x": { "field": "month", "type": "ordinal", "title": null}
          },
          "transform": [
            { "filter": "datum['death_code'] == '#{code}'"}
          ],
          "layer": [
            {
              "mark": { "type": "line", "point": true, "clip": true },
              "params": [
                {
                  "name": "year",
                  "select": {"type": "point", "fields": ["year"]},
                  "bind": {"legend": "mouseover"}
                }
              ],
              "encoding": {
                "y": {
                  "field": "#{$target}",
                  "type": "quantitative",
                  "scale": { #{domain_str} },
                  "title": null
                },
                "color": {
                  "field": "year",
                  "type": "ordinal",
                  "title": "#{{ja: '年', en: 'Year'}[$l]}",
                  "scale": {"scheme": "magma"},
                  "sort": "descending"
                },
                "opacity": {
                  "condition": {"param": "year", "value": 1},
                  "value": 0.1
                }
              }
            },
            {
              "transform": [
                {
                  "pivot": "year",
                  "value": "#{$target}",
                  "groupby": ["month"]
                }
              ],
              "mark": { "type": "rule", "clip": true },
              "encoding": {
                "opacity": {
                  "condition": {"value": 0.3, "param": "hover", "empty": false},
                  "value": 0
                },
                "tooltip": [
EOF
        Years.each do |k, v|
            next if v[:sel] != 'checked'
            year = k.gsub(/^year_/,'')
            print <<EOF
                  {"field": "#{year}", "type": "quantitative"},
EOF
    end
        print <<EOF
                  {"title": "#{{ja:'月',en:'Month'}[$l]}","field": "month", "type": "nominal"}
                ]
              },
              "params": [
                {
                  "name": "hover",
                  "select": {
                    "type": "point",
                    "fields": ["month"],
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
end # def print_monthly

# 選択した死因の年次Vega-Liteグラフ定義を出力する。
# Render yearly Vega-Lite chart specifications for the selected causes of death.
def print_yearly(death_codes)

    print <<EOF
      },
      "columns": #{$columns},
      "concat": [
EOF

    $firstflag = true
    death_codes.each do |code|
        if code =~ /population/
            cause = {sel: 'checked', ja: '人口', en: 'Population'}
        else
            cause = Death_codes[code]
        end
        domain_str = $scale_mode == 'expanded' ? ($expanded_domains[code] || '"domain": "unaggregated"') : ((code == 'all' && $scale_mode == 'aligned_except_all') ? '"domain": "unaggregated"' : $domain_str[$scale_mode])
        next if ! cause[:sel]
        puts '        ,' if ! $firstflag
        $firstflag = false
        title = {ja: cause[$l].slice(0..25), en: cause[$l].slice(0..49)}[$l]
        print <<EOF
        {
          "height": #{$height},
          "width": {"step": #{$step}},
          "title": ["#{title}"],
          "encoding": {
            "x": { "field": "year", "type": "ordinal", "title": null}
          },
          "transform": [
            { "filter": "datum['death_code'] == '#{code}'"}
          ],
          "layer": [
            {
              "mark": { "type": "bar", "clip": true},
              "params": [
                {
                  "name": "year",
                  "select": {"type": "point", "fields": ["year"]},
                  "bind": {"legend": "mouseover"}
                }
              ],
              "encoding": {
                "y": {
                  "field": "yearly_#{$target}",
                  "type": "quantitative",
                  "scale": { #{domain_str} },
                  "title": null
                },
                "color": {
                  "field": "year",
                  "type": "ordinal",
                  "title": "#{{ja: '年', en: 'Year'}[$l]}",
                  "scale": {"scheme": "magma"},
                  "sort": "descending"
                },
                "tooltip": {"field": "yearly_#{$target}", "type": "quantitative"},
                "opacity": {
                  "condition": {"param": "year", "value": 1},
                  "value": 0.1
                }
              }
            }
EOF
        [2019, 2020].each do |until_year|
            print <<EOF
            ,
            {
              "usermeta": {"regression": "#{until_year}"},
              "transform": [
                { "filter": "regressionChoice == '#{until_year}'"},
                { "filter": "datum['year'] <= #{until_year}"},
                { "filter": "datum['regression_#{until_year}'] != null"}
              ],
              "mark": { "type": "line", "color": "#00ff00", "strokeWidth": 4, "clip": true},
              "encoding": {
                "y": {
                  "field": "regression_#{until_year}",
                  "type": "quantitative",
                  "title": null
                }
              }
            },
            {
              "usermeta": {"regression": "#{until_year}"},
              "transform": [
                { "filter": "regressionChoice == '#{until_year}'"},
                { "filter": "datum['year'] >= #{until_year}"},
                { "filter": "datum['regression_#{until_year}'] != null"}
              ],
              "mark": { "type": "line", "color": "#ff0000", "strokeWidth": 4, "clip": true},
              "encoding": {
                "y": {
                  "field": "regression_#{until_year}",
                  "type": "quantitative",
                  "title": null
                }
              }
            }
EOF
        end
            print <<EOF
          ]
        }
EOF
    end
end # def print_yearly

# 年次の比率・派生系列グラフを出力する。
# Render yearly ratio and derived-series charts.
def print_yearly_ratio(subtype, appdx, formats)
    rank_sort = $topflag ? '"sort": {"field": "rank", "order": "ascending"},' : ''
    category_count = [$death_codes.count, 1].max
    year_count = [$years.count, 1].max
    bar_size = [[(2400.0 / category_count / year_count * 0.55).floor, 2].max, 12].min
    category_width = 1200.0 / category_count
    offset_padding = 0

    print <<EOF
      },
      "width": "container",
      "height": #{$height},
      "encoding": {
        "x": {
          "field": "death_cause",
          "type": "ordinal",
          #{rank_sort}
          "title": null,
          "axis": { "labels": true, "labelLimit": 400, "labelAngle": 90 },
        },
        "y": {
          "field": "#{subtype}#{appdx}",
          "type": "quantitative",
          "axis": { "labels": true, "format": "#{formats[0]}" },
          "title": null
        },
        "xOffset": {
          "field": "year",
          "scale": {"paddingInner": 0, "paddingOuter": #{offset_padding}}
        }
      },
      "transform": [
        {"filter": "#{$filter_str}"}
      ],
      "layer": [
        {
          "mark": {"type": "bar", "clip": true},
          "params": [
            {
              "name": "year",
              "select": {"type": "point", "fields": ["year"]},
              "bind": {"legend": "mouseover"}
            }
          ],
          "encoding": {
            "color": {
              "field": "year",
              "type": "ordinal",
              "title": "#{{ja: '年', en: 'Year'}[$l]}",
              "scale": {"scheme": "magma"},
              "sort": "descending"
            },
            "tooltip": [
              { "field": "#{subtype}#{appdx}", "format": "#{formats[1]}" },
              { "field": "yearly_sum#{appdx}", "format": "#{formats[2]}" },
              { "field": "yearly_avg#{appdx}", "format": "#{formats[3]}" }
            ],
            "opacity": {
              "condition": {"param": "year", "value": 1},
              "value": 0.1
            }
          }
        }
EOF
end # def print_yearly_ratio

death_code_terms = if $topflag
                       Death_codes.keys
                   else
                       Death_codes.select{|k, v| v[:sel] == 'checked'}.keys
                   end
death_code_terms = death_code_terms.map{|code| code == 'all' ? '00000' : code}
per_capita_selected = Per_capita['true'][:sel] == 'checked'
population_selected = $cgi['category'] =~ /population/
needs_population = $adjustment != 'none' || per_capita_selected || population_selected
required_years = ($years + $years_ref + $years_context).map(&:to_i).uniq.sort

should = [
    {
        'bool' => {
            'must' => [
                {'term' => {'category' => 'death'}},
                {'terms' => {'death_code' => death_code_terms}},
            ]
        }
    }
]
if needs_population
    should.push({
        'bool' => {
            'must' => [
                {'term' => {'category' => 'pop'}},
                {'term' => {'type' => 'conf'}},
            ]
        }
    })
end

# 集計方法に必要な年齢fieldだけを取得し、巨大な不要応答を避ける。
# Fetch only the age fields required by the selected aggregation mode.
age_sources = if $adjustment != 'none' || per_capita_selected
                  ($ages.map{|k, _v| "age_#{k}"} + ['age_85over'] +
                   ($all_ages_selected ? ['age_all'] : [])).uniq
              elsif $all_ages_selected
                  ['age_all']
              else
                  $ages.map{|k, _v| "age_#{k}"}
              end

data0 = elastic_search(
    :index => 'mstats',
    :filter => [
        {'terms' => {'year' => required_years}},
        {'term' => {'loc_code' => 'jpn'}},
        {'term' => {'sex' => $sex}},
        {'exists' => {'field' => 'yearmonth'}},
    ],
    :should => should,
    :source => ['id', 'category', 'date', 'year', 'month', 'death_code', 'death_cause', 'sex', 'type'] +
               age_sources,
    #:debug => 'SHOWONLY',
)

#pp data0
#exit


#
# data0 -> $data
#
$data = Hash.new
data0.each do |datum0|
    source_year = datum0[:year].to_s
    next if ! Years[source_year] ||
            (Years[source_year][:sel] != 'checked' &&
             ! $years_ref.find{|v| v == source_year} &&
             ! $years_context.find{|v| v == source_year})
    #next if datum0['_source']['type'] && datum0['_source']['type'] != 'confirmed'
    datum = {
        'doc_id' => datum0[:id] || datum0[:_id]
    }
    datum0.each do |key, v|
        k = key.to_s
        if k =~ /^category/
            datum[k] = (v == 'pop' ? 'population' : v)
            if v == 'pop'
                datum['death_code'] = 'population'
                datum['death_cause'] = '人口'
                datum['death_cause_ja'] = '人口'
                datum['death_cause_en'] = 'Population'
            end
        elsif k =~ /^date|^age|^sex/
            datum[k] = v
        elsif k == 'year'
            datum[k] = v.to_s
        elsif k =~ /^death_code/
            internal_code = (v == '00000' ? 'all' : v)
            datum[k] = internal_code
            if Death_codes[internal_code]
                datum['death_cause'] = "#{v}: #{Death_codes[internal_code][$l]}"
                datum['death_cause_ja'] = "#{v}: #{Death_codes[internal_code][:ja]}"
                datum['death_cause_en'] = "#{v}: #{Death_codes[internal_code][:en]}"
            end
        elsif k =~ /^month/
            datum[k] = sprintf('%02d', v.to_i)
        end
    end
    sum = if $all_ages_selected
              datum['age_all'].to_i
          elsif datum['category'] == 'population' && $includes_all_oldest &&
                datum['age_85over'].to_f > 0
              ($ages.keys - OldestAgeKeys).sum{|age| datum["age_#{age}"].to_i} +
                  datum['age_85over'].to_i
          else
              $ages.sum{|age, v| datum["age_#{age}"].to_i}
          end
    datum['sum'] = sum
    $data[datum['doc_id']] = datum
end

#
# Adjust
#
$data = $data.sort.to_h
$selected_years = Years.select{|k, v| v[:sel] == 'checked'}.keys
$population_by_period = $data.each_value.select{|datum| datum['category'] == 'population'}.
    to_h{|datum| [[datum['year'], datum['month'], datum['sex']], datum]}
$data.each_value{|datum| datum['sum_none'] = datum['sum']}

if $adjustment != 'none'
    last_pop = $population_by_period.values.
        select{|datum| $selected_years.include?(datum['year'])}.
        max_by{|datum| [datum['year'].to_i, datum['month'].to_i]}
    adjustment_groups = $ages.keys.
                            select{|age| StandardPopulation2015[age]}.
                            map{|age| [[age], StandardPopulation2015[age]]}
    if $ages['95_99'] || $ages['100over']
        adjustment_groups.push([['95_99', '100over'], StandardPopulation2015['95over']])
    end

    $data.each_value do |datum|
        population = $population_by_period[[datum['year'], datum['month'], datum['sex']]]
        next if ! population

        latest_groups = $ages.keys.map{|age| [age]}
        standard_groups = adjustment_groups
        if $includes_all_oldest && population['age_85over'].to_f > 0
            latest_groups = ($ages.keys - OldestAgeKeys).map{|age| [age]} + [OldestAgeKeys]
            standard_groups = adjustment_groups.reject{|ages, _weight| (ages & OldestAgeKeys).any?} +
                [[OldestAgeKeys, StandardPopulation2015['85_89'] +
                                  StandardPopulation2015['90_94'] +
                                  StandardPopulation2015['95over']]]
        end
        if $adjustment == 'latest'
            datum['sum_latest'] = latest_groups.sum{|ages|
                deaths = ages == OldestAgeKeys && datum['age_85over'].to_f > 0 ?
                    datum['age_85over'].to_f : ages.sum{|age| datum["age_#{age}"].to_f}
                denominator = ages == OldestAgeKeys ? population['age_85over'].to_f :
                                                      population["age_#{ages.first}"].to_f
                target = ages.sum{|age| last_pop["age_#{age}"].to_f}
                denominator > 0 ? deaths * target / denominator : 0
            }.round(2)
        else
            datum['sum_standard2015'] = standard_groups.sum{|ages, standard_population|
                deaths = ages == OldestAgeKeys && datum['age_85over'].to_f > 0 ?
                    datum['age_85over'].to_f : ages.sum{|age| datum["age_#{age}"].to_f}
                denominator = ages == OldestAgeKeys ? population['age_85over'].to_f :
                                                      ages.sum{|age| population["age_#{age}"].to_f}
                denominator > 0 ? deaths * standard_population / denominator : 0
            }.round(2)
        end
    end
end

$data.each_value{|datum| datum['sum'] = datum["sum_#{$adjustment}"]}

#
# Prepare for per-Capita
#
if per_capita_selected
    $data.each_value do |datum|
        population = $population_by_period[[datum['year'], datum['month'], datum['sex']]]
        next if ! population

        (['sum'] + $ages.map{|k, _v| "age_#{k}" }).each do |age|
            #puts "+++++++++++++++++++++++++++ #{age}"
            if datum[age] && population[age] && (pop = population[age].to_i) > 0
                age_per_capita = "#{age}_per_capita"
                datum[age_per_capita] = ((datum[age].to_f * 100000.00000) / pop).round(6)
            else
                next
            end
            #puts "#{id} #{age}: #{datum[age]} #{pop} #{datum[age_per_capita]}"
        end
    end
end

#
# Prepare for Yearly ratio
#
sums = Hash.new

if $topflag
    $death_codes = Death_codes.map{|k, v| k}
else
    $death_codes = Death_codes.select{|k,v| v[:sel] == 'checked'}.map{|k, v| k}
end
if $cgi['category'] =~ /population/
    $death_codes.unshift('population')
end

data_by_code_year = Hash.new{|hash, key| hash[key] = []}
$data.each_value do |datum|
    data_by_code_year[[datum['death_code'], datum['year']]] << datum
end

#pp $death_codes
#pp $topflag
#exit

$death_codes.each do |death_code|
    sums[death_code] = Hash.new
    $years_ref.each do |year|
        sums[death_code][year] = data_by_code_year[[death_code, year]].sum{|datum| datum['sum']}
    end
end

#pp $death_codes
#pp sums
#exit

sums_per_capita = Hash.new
if per_capita_selected
    $death_codes.each do |death_code|
        sums_per_capita[death_code] = Hash.new
        $years_ref.each do |year|
            sums_per_capita[death_code][year] = data_by_code_year[[death_code, year]].sum{|datum| datum['sum_per_capita']}.round(6)
        end
    end
end

avgs = Hash.new
$death_codes.each do |death_code|
    next if sums[death_code].count == 0
    avgs[death_code] = (sums[death_code].sum{|k, v| v}.to_f / sums[death_code].count).round(6)
end

avgs_per_capita = Hash.new
if per_capita_selected
    $death_codes.each do |death_code|
        next if sums[death_code].count == 0
        avgs_per_capita[death_code] = (sums_per_capita[death_code].sum{|_k, v| v}.to_f / sums_per_capita[death_code].count).round(6)
    end
end

$death_codes.each do |death_code|
    ($years + $years_context).uniq.each do |year|
        values = data_by_code_year[[death_code, year]]
        datum = values.find{|value| value['month'] == '01'}
        next if ! datum
        datum['yearly_sum'] =
            values.sum{|v| v['sum']}
        if death_code == 'population'
            datum['yearly_sum'] /= 12
        end
        if per_capita_selected
            datum['yearly_sum_per_capita'] =
                values.sum{|v| v['sum_per_capita']}.round(6)
        end
        datum['yearly_avg'] = avgs[death_code]
        datum['yearly_avg_per_capita'] = avgs_per_capita[death_code] if per_capita_selected

        if datum['yearly_sum'] && datum['yearly_avg']
            datum['yearly_diff'] = datum['yearly_sum'] - datum['yearly_avg']
        end
        if per_capita_selected && datum['yearly_sum_per_capita'] && datum['yearly_avg_per_capita']
            datum['yearly_diff_per_capita'] =
                datum['yearly_sum_per_capita'] - datum['yearly_avg_per_capita']
        end

        next if ! avgs[death_code] || avgs[death_code] == 0

        datum['yearly_ratio'] = (datum['yearly_sum'] / avgs[death_code] - 1).round(6)
        if per_capita_selected
            if avgs_per_capita[death_code] > 0
                datum['yearly_ratio_per_capita'] = (datum['yearly_sum_per_capita'] / avgs_per_capita[death_code] - 1).round(6)
            else
                datum['yearly_ratio_per_capita'] = 0
            end
        end
        #puts "#{datum['yearly_ratio_per_capita']} #{datum['yearly_sum_per_capita']} #{avgs_per_capita[death_code]}"
    end
end

#
# Top 20 を検索
#
if $topflag
    #$death_codes = $data.select{|k, v| v['yearly_diff'] && v['year'] == $last_year}.
    #                  sort{|(ak, av), (bk, bv)| bv['yearly_diff'] <=> av['yearly_diff']}.
    #                  map{|k, v| v['death_code']}.slice(0, 20)

    $death_codes = Array.new
    if Death_codes['all'][:sel] == 'checked'
        $death_codes.push('all')
    end
    if Death_codes['02100'][:sel] == 'checked'
        $death_codes.push('02100')
    end
    count = 1
    yearly_diff = (Per_capita['true'][:sel] == 'checked') ?
                       'yearly_diff_per_capita' : 'yearly_diff'
    $data.
        select{|k, v| v[yearly_diff] && v['year'] == $last_year}.
        sort{|(ak, av), (bk, bv)| (Top['20'][:sel] == 'selected' ||
                                   Top['dai10'][:sel] == 'selected' ||
                                   Top['cancer20'][:sel] == 'selected' ||
                                   Top['cancer10'][:sel] == 'selected' ) ?
                 bv[yearly_diff] <=> av[yearly_diff] :
                 av[yearly_diff] <=> bv[yearly_diff]}.
        map{|k, v| v['death_code']}.
        each do |code|
        if Top['cancer20'][:sel] == 'selected' || Top['cancer10'][:sel] == 'selected'
            next if code !~ /^021..$/ || code =~ /^02100$/
        elsif Top['20'][:sel] == 'selected'
            if code =~ /^..000$/ || code !~ /^...00$/ || code == 'all'
                next if code !~ /^201..$/ || code !~ /^021..$/
            end
            next if code =~ /^20100$/ || code =~ /^02100$/
        elsif Top['dai10'][:sel] == 'selected'
            next if code !~ /^..000$/
        end
        $death_codes.push(code)
        count += 1
        break if count > 20 ||
                 ((Top['dai10'][:sel] == 'selected' || Top['cancer10'][:sel] == 'selected') &&
                  count > 10)
    end

    #$data = $data.select{|k, v| Years[v['year']][:sel] == 'checked' &&
    #                     $death_codes.find{|code| code == v['death_code']}}

    $data2 = Hash.new
    $data.each do |k, v|
        next if Years[v['year']][:sel] != 'checked' &&
                ! $years_context.include?(v['year'])
        v2 = $death_codes.find{|code| code == v['death_code']}
        next if ! v2
        index = $death_codes.index(v['death_code']) + 1
        index -= 1 if Death_codes['all'][:sel] == 'checked'
        index -= 1 if Death_codes['02100'][:sel] == 'checked'
        index = 0 if index < 0
        prefix = sprintf('%02d: ', index)
        %w[death_cause death_cause_ja death_cause_en].each do |field|
            v[field] = prefix + v[field][7..-1] if v[field]
        end
        v['rank'] = index
        $data2[k] = v
    end
    $data =  $data2
end

#
# 年ごとの場合は、指定年までの一次回帰線を計算する。
# For yearly views, calculate a linear regression through the selected year.
#
class Array
  def reg_line(y)
    # 以下の場合は例外スロー
    # - 引数の配列が Array クラスでない
    # - 自身配列が空
    # - 配列サイズが異なれば例外
    raise "Argument is not a Array class!"  unless y.class == Array
    raise "Self array is nil!"              if self.size == 0
    raise "Argument array size is invalid!" unless self.size == y.size

    # x の総和
    sum_x = self.inject(0) { |s, a| s += a }
    # y の総和
    sum_y = y.inject(0) { |s, a| s += a }
    # x^2 の総和
    sum_xx = self.inject(0) { |s, a| s += a * a }
    # x * y の総和
    sum_xy = self.zip(y).inject(0) { |s, a| s += a[0] * a[1] }
    # 切片 a
    a  = sum_xx * sum_y - sum_xy * sum_x
    a /= (self.size * sum_xx - sum_x * sum_x).to_f
    # 傾き b
    b  = self.size * sum_xy - sum_x * sum_y
    b /= (self.size * sum_xx - sum_x * sum_x).to_f
    {intercept: a, slope: b}
  end
end

# submitで確定した年齢調整・人口あたり系列について回帰線を計算する。
regression_field = Per_capita['true'][:sel] == 'checked' ? 'yearly_sum_per_capita' : 'yearly_sum'
[2019, 2020].each do |until_year|
    $death_codes.each do |death_code|
        data = ($years + $years_ref + $years_context).uniq.flat_map{|year|
            data_by_code_year[[death_code, year]]
        }.select{|datum|
            datum['month'] == '01' && datum[regression_field]
        }.sort_by{|datum| datum['year'].to_i}
        reference = data.select{|datum| datum['year'].to_i <= until_year}
        next if reference.count < 2
        reg = reference.map{|datum| datum['year'].to_i}.reg_line(
            reference.map{|datum| datum[regression_field].to_f}
        )
        data.each do |datum|
            datum["regression_#{until_year}"] =
                (reg[:slope] * datum['year'].to_i + reg[:intercept]).round(6)
        end
    end
end

# 年次グラフでは年次集計値を持つ1月レコードだけをブラウザへ渡す。
$data = $data.select{|id, datum| datum['month'] == '01'} if $graph_key =~ /^yearly/

puts JSON.pretty_generate($data.values.sort{|a, b| a['date']<=>b['date']}).gsub(/\n/, "\n        ")

$domain_str = {'individual' => '"domain": "unaggregated"', 'aligned' => '"domain": "unaggregated"', 'aligned_except_all' => '"domain": "unaggregated"'}
$expanded_domains = {}

$filter_str = ''

$target = 'sum'
$target = 'sum_per_capita' if Per_capita['true'][:sel] == 'checked'

p = ($graph_key == 'yearly') ? 'yearly_' : ''
s = (Per_capita['true'][:sel] == 'checked') ? '_per_capita' : ''
codes = $data.values.map{|v| v['death_code']}.compact.uniq
%w[aligned aligned_except_all].each do |mode|
    max = $data.values.select{|v| v['death_code'] != 'population' && (mode == 'aligned' || v['death_code'] != 'all') && v["#{p}sum#{s}"]}.
              max{|a, b| a["#{p}sum#{s}"].to_f <=> b["#{p}sum#{s}"].to_f}
$domain_str[mode] = '"domain": [ 0, ' + (max["#{p}sum#{s}"].to_f * 1.05).to_s + ' ]' if max
end

$data.values.group_by{|v| v['death_code']}.each do |code, rows|
    values = rows.map{|v| v["#{p}sum#{s}"].to_f}.select(&:finite?)
    next if values.empty?
    low = [values.min * 0.9, 0].max
    $expanded_domains[code] = '"domain": [ ' + low.to_s + ', ' + (values.max * 1.1).to_s + ' ]'
end

debug_codes = %w[all 02000 18000]
$domain_debug = $domain_str.merge('expanded' => $expanded_domains).transform_values do |domain|
    if domain.is_a?(Hash)
        domain
    else
    debug_codes.to_h{|code| [code, (domain == $domain_str['aligned_except_all'] && code == 'all') ? '"domain": "unaggregated"' : domain]}
    end
end
$domain_debug = {current: $scale_mode, current_domains: $domain_debug[$scale_mode], modes: $domain_debug}
#pp p, s, $domain_str
#exit


death_codes2 = $cgi['death_codes'].split(/,|~|、/)
$death_codes = death_codes2 if !$topflag && $death_codes.sort == death_codes2.sort

if $graph_key =~ /^monthly$/
    print_monthly($death_codes)
elsif $graph_key =~ /^yearly$/
    print_yearly($death_codes)
elsif $graph_key =~ /^yearly_/
    $years.each do |year|
        if $filter_str == ''
            $filter_str = "datum['year'] == #{year}"
        else
            $filter_str += "|| datum['year'] == #{year}"
        end
    end
    appdx = (Per_capita['true'][:sel] == 'checked') ? '_per_capita' : ''
    if $graph_key =~ /^yearly_diff/
        if Per_capita['true'][:sel] == 'checked'
            formats = [ '.0d', '.0d', '.3f', '.3f' ]
        else
            formats = [ '.0d', '.0d', '.0d', '.2f' ]
        end
    else
        if Per_capita['true'][:sel] == 'checked'
            formats = [ '.0%', '.0%', '.3f', '.3f' ]
        else
            formats = [ '.0%', '.0%', '.2f', '.2f' ]
        end
    end
    print_yearly_ratio($graph_key, appdx, formats)
end

print <<EOF
      ]
    };
    const instantBaseSpec = structuredClone(spec);
    const instantBaseValues = structuredClone(spec.data.values);
    const instantTopResult = #{$topflag};
    const instantShowYearlyOverview = #{$show_yearly_overview ? 'true' : 'false'};
    const instantYearlyField = #{JSON.generate(Per_capita['true'][:sel] == 'checked' ? 'yearly_sum_per_capita' : 'yearly_sum')};
    const instantSearchedDeathCodes = #{JSON.generate($topflag ? $death_codes : [])};
    function setScaleDomains(chart, values, scaleMode) {
      if (!chart || typeof chart != 'object') return;
      var domainText = rubyDomainStrings[scaleMode];
      if (Array.isArray(chart.concat)) {
        chart.concat.forEach(child => setScaleDomains(child, values, scaleMode));
        return;
      }
      var isAllCause = (chart.transform || []).some(transform =>
        typeof transform.filter == 'string' && transform.filter.includes("death_code'] == 'all'"));
      var codeMatch = (chart.transform || []).map(transform => String(transform.filter || '').match(/death_code.*?==\s*['"]([^'"]+)['"]/)).find(Boolean);
      var code = isAllCause ? 'all' : (codeMatch ? codeMatch[1] : null);
      var fields = [];
      function visit(value) {
        if (Array.isArray(value)) return value.forEach(visit);
        if (!value || typeof value != 'object') return;
        if (value.y && value.y.field) fields.push(value.y.field);
        Object.values(value).forEach(visit);
      }
      visit(chart);
      function update(value) {
        if (Array.isArray(value)) return value.forEach(update);
        if (!value || typeof value != 'object') return;
        if (value.y && value.y.field) {
          value.y.scale ||= {};
          var expandedText = code ? rubyExpandedDomains[code] : null;
          if (scaleMode == 'expanded' && expandedText) value.y.scale = Object.assign(value.y.scale || {}, JSON.parse('{' + expandedText + '}'));
          else if (domainText && !(scaleMode == 'aligned_except_all' && isAllCause)) value.y.scale = Object.assign(value.y.scale || {}, JSON.parse('{' + domainText + '}'));
          else if (!domainText || scaleMode == 'individual') delete value.y.scale.domain;
        }
        Object.values(value).forEach(update);
      }
      update(chart);
    }

    function buildYearlyOverviewSpec(values, language, columns) {
      var yearTitle = language == 'ja' ? '年' : 'Year';
      var panels = instantSearchedDeathCodes.map(code => {
        var sample = values.find(datum => datum.death_code == code);
        var title = sample ? sample.death_cause : code;
        var layers = [
          {
            mark: {type: 'bar', clip: true},
            encoding: {
              y: {field: instantYearlyField, type: 'quantitative', scale: {}, title: null},
              color: {
                field: 'year', type: 'ordinal', title: yearTitle,
                scale: {scheme: 'magma'}, sort: 'descending'
              },
                tooltip: {field: instantYearlyField, type: 'quantitative'}
            }
          }
        ];
        ['2019', '2020'].forEach(untilYear => {
          layers.push({
            usermeta: {regression: untilYear},
            transform: [
              {filter: `regressionChoice == '${untilYear}'`},
              {filter: `datum['year'] <= ${untilYear}`},
              {filter: `datum['regression_${untilYear}'] != null`}
            ],
            mark: {type: 'line', color: '#00ff00', strokeWidth: 4, clip: true},
            encoding: {y: {field: `regression_${untilYear}`, type: 'quantitative', scale: {}, title: null}}
          });
          layers.push({
            usermeta: {regression: untilYear},
            transform: [
              {filter: `regressionChoice == '${untilYear}'`},
              {filter: `datum['year'] >= ${untilYear}`},
              {filter: `datum['regression_${untilYear}'] != null`}
            ],
            mark: {type: 'line', color: '#ff0000', strokeWidth: 4, clip: true},
            encoding: {y: {field: `regression_${untilYear}`, type: 'quantitative', scale: {}, title: null}}
          });
        });
        return {
          height: #{$height},
          width: {step: #{$step}},
          title: [title],
          encoding: {x: {field: 'year', type: 'ordinal', title: null}},
          transform: [{filter: `datum['death_code'] == '${code}'`}],
          layer: layers
        };
      });
      var yearlySpec = {
        '$schema': 'https://vega.github.io/schema/vega-lite/v5.json',
        config: structuredClone(instantBaseSpec.config),
        params: structuredClone(instantBaseSpec.params),
        data: {name: 'stats', values: values},
        columns: columns,
        concat: panels
      };
      return yearlySpec;
    }

    function checkSearchedDeathCodes() {
      if (!instantTopResult) return;
      document.querySelectorAll('input[name="death_code"]').forEach(checkbox => {
        checkbox.checked = instantSearchedDeathCodes.includes(checkbox.value);
        var rank = instantSearchedDeathCodes.indexOf(checkbox.value);
        if (rank >= 0) checkbox.dataset.searchRank = rank + 1;
        else delete checkbox.dataset.searchRank;
      });
      updateDeathCodeSummary();
    }

    async function renderInstantSelection() {
      var regression = document.querySelector('select[name="regression"]').value;
      var columns = Number(document.querySelector('select[name="columns"]').value);
      var scaleMode = document.querySelector('select[name="scale"]').value;
      var nextSpec = structuredClone(instantBaseSpec);
      if (nextSpec.concat) nextSpec.columns = columns;
      setScaleDomains(nextSpec, nextSpec.data.values, scaleMode);
      await vegaEmbed("#vis", nextSpec, {mode: "vega-lite"});
      if (instantShowYearlyOverview && document.getElementById('vis-yearly')) {
        var yearlySpec = buildYearlyOverviewSpec(nextSpec.data.values, currentLanguage, columns);
        setScaleDomains(yearlySpec, yearlySpec.data.values, scaleMode);
        await vegaEmbed("#vis-yearly", yearlySpec, {mode: "vega-lite"});
      }

      var url = new URL(window.location.href);
      url.searchParams.set('regression', regression);
      url.searchParams.set('columns', columns);
      url.searchParams.set('scale', scaleMode);
      history.replaceState(null, '', url);

    }
    Object.assign(rubyDomainStrings, #{JSON.generate($domain_str)});
    Object.assign(rubyExpandedDomains, #{JSON.generate($expanded_domains)});
    window.renderInstantSelection = renderInstantSelection;
    checkSearchedDeathCodes();
    // 初回表示ではJSONを書き換えず、Ruby生成specをそのまま描画する。
    vegaEmbed("#vis", spec, {mode: "vega-lite"}).catch(console.warn);
    if (instantShowYearlyOverview && document.getElementById('vis-yearly')) {
      var initialColumns = Number(document.querySelector('select[name="columns"]').value);
      var initialYearlySpec = buildYearlyOverviewSpec(
        instantBaseValues, currentLanguage, initialColumns
      );
      setScaleDomains(
        initialYearlySpec, initialYearlySpec.data.values,
        document.querySelector('select[name="scale"]').value
      );
      vegaEmbed("#vis-yearly", initialYearlySpec, {mode: "vega-lite"}).catch(console.warn);
    }
    /*
    const domainDebug = #{JSON.generate($domain_debug)};
    const debug = document.createElement('pre');
    debug.id = 'domain-debug';
    debug.textContent = 'domain debug\\n' + JSON.stringify(domainDebug, null, 2);
    document.body.appendChild(debug);
    */
  </script>
EOF

if ! $iframeflag
    print <<EOF
  <p class=r>
    © 2022 <a href="https://medicalfacts.info">MedicalFacts.info</a> powered by <a href="https://www.elastic.co/" target><img src="https://images.contentstack.io/v3/assets/bltefdd0b53724fa2ce/blt280217a63b82a734/5bbdaacf63ed239936a7dd56/elastic-logo.svg" style="height: 2em"></a> <a href="https://vega.github.io/vega-lite/" style="text-decoration: none;"><img src="https://raw.githubusercontent.com/vega/logos/master/assets/VL_Color%40128.png" style="width: 2em;"> Vega-Lite</a>
  <p class=l>
  <hr>
    #{{'ja': 'データ元', en: 'Data sources'}[$l]}:
    <ul>
      <li> <a target=_blank href="https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0"> e-Stat #{{ja: '統計で見る日本 人口動態統計 月報（概数） 月次', en: 'Statistics of Japan, Population Dynamics, Monthly Reports (Estimated)'}[$l]} </a>
      <li> <a target=_blank href="https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=7&year=20220&month=0&tclass1=000001053058&tclass2=000001053061&tclass3=000001053074&tclass4=000001053089&tclass5val=0">e-Stat #{{ja: '統計で見る日本 人口動態統計 確定数 保管統計表　都道府県編（報告書非掲載表）死因 年次', en: 'Statistics of Japan, Population Dynamics, Prefectural Breakdown, Causes of Death, Annual Reports (Confirmed)'}[$l]}</a>
      <li> <a target=_blank href="https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0"> e-Stat #{{ja: '統計で見る日本 人口推計 各月1日現在人口 月次', en: 'Statistics of Japan, Population Estimation, As of the 1st of Each Month, Monthly Reports (Estimated and Confirmed)'}[$l]}</a>
    </ul>
  </div>
</body>
</html>
EOF
end
