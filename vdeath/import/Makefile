SHELL := /bin/zsh
.SHELLFLAGS := -eu -c

SRC_DIR ?= /Users/magician/icloud/vdeath/src
CZECH_SRC_DIR ?= /Users/magician/work/vdeath-src/Czech
OUT_DIR ?= ../outputs
RUBY ?= ruby
SCRIPT := ./vdeathp.rb
RUN := $(RUBY) $(SCRIPT)
GAMMA_SCRIPT := ./kcor_gamma.rb
INDIV_INDEX ?= indiv20260721
INDIV_MAPPING := ../config/elasticsearch/$(INDIV_INDEX).json
INDIV_FILES := $(wildcard $(OUT_DIR)/*_IND-WKA.csv)
INDIV_PUBLIC_DIR ?= /home/magician/fujikawa/pub/kkcor
INDIV_LOGSTASH_CONF ?= ../config/logstash/indiv.conf
KKCOR_HOST ?= fujikawa.org
KKCOR_DIR ?= /home/magician/fujikawa/pub/kkcor
INDIVDTH_INDEX ?= indivdth20260721
INDIVDTH_FILE := $(OUT_DIR)/jp271004_Osaka-Osaka-JP_DTH-WKA.csv
AGES := 00-09,10-19,20-29,30-39,40-49,50-59,60-69,70-79,80-89,90-99,100+,80+,all
CITIES := jp132101 jp141500 jp221309 jp222267 jp232068 jp232076 jp271004 jp442054
CZECH_INPUT := $(CZECH_SRC_DIR)/Otevrena-data-NR-26-30-COVID-19-prehled-populace-2024-01.csv
CZECH_HEADER := ./headers/czech-2024-01.csv
CZECH_NAME := cze_Czech-Republic
CZECH_IND := $(OUT_DIR)/$(CZECH_NAME)_IND-WKA.csv
CZECH_PY := $(OUT_DIR)/$(CZECH_NAME)_PY.csv
CZECH_AFTERDOSE := $(OUT_DIR)/$(CZECH_NAME)_PY-WKD.csv
CZECH_CUMD := $(OUT_DIR)/$(CZECH_NAME)_CUMD-WK.csv
CZECH_RISK := $(OUT_DIR)/$(CZECH_NAME)_CUMD-WK-G.csv
CZECH_GAMMA_PARAMS := $(OUT_DIR)/$(CZECH_NAME)_GAMMA-CONSTANT-PARAMS.csv
CZECH_GAMMA_SERIES := $(OUT_DIR)/$(CZECH_NAME)_GAMMA-CONSTANT-SERIES.csv
CZECH_WEEKLY_DATE_SEED ?= v1
CZECH_SOURCE_ROWS := 12597668
CZECH_POPULATION_ROWS := 10314685
WEEKLY_DATE_SEED ?= v1
comma := ,

.PHONY: all cze cze-all cze-ind cze-py cze-afterdose cze-kcor cze-gamma indiv-check indiv indivdth publish-kkcor $(CITIES)
all: $(CITIES)

# 日本語: チェコ公式週次個票を一度共通INDへ正規化し、vdeathとKCORを同じ入力から生成する。
# English: Normalize Czech official weekly records once, then generate vdeath and KCOR from the same IND input.
cze: cze-py cze-kcor cze-gamma
cze-all: cze cze-afterdose
cze-ind: $(CZECH_IND)
cze-py: $(CZECH_PY)
cze-afterdose: $(CZECH_AFTERDOSE)

$(CZECH_IND): $(CZECH_INPUT) $(CZECH_HEADER) $(SCRIPT) Makefile
	@mkdir -p "$(OUT_DIR)"
	$(RUN) anonymize --headers "$(CZECH_HEADER)" --skip-source-header --first-infection-only --iso-week-dates \
	  --areacode cze --area "Czech Republic" --areaj "チェコ" --age-reference 2024-09-02 \
	  --progress-total $(CZECH_SOURCE_ROWS) \
	  --report "$(OUT_DIR)/$(CZECH_NAME)_IMPORT-REPORT.json" \
	  --output "$@" "$(CZECH_INPUT)"

$(CZECH_PY): $(CZECH_IND) $(SCRIPT) Makefile
	$(RUN) personyear --steps 1,3,6,all --ages "$(AGES)" --start 2021-02-01 --until 2024-09-02 \
	  --age-reference 2024-09-02 \
	  --progress-total $(CZECH_POPULATION_ROWS) \
	  --spread-weekly-dates "$(CZECH_WEEKLY_DATE_SEED)" \
	  --output "$@" "$(CZECH_IND)"

$(CZECH_AFTERDOSE): $(CZECH_IND) $(SCRIPT) Makefile
	$(RUN) afterdose --weeks 1-99 --ages 80+,all --until 2024-09-02 \
	  --spread-weekly-dates "$(CZECH_WEEKLY_DATE_SEED)" \
	  --output "$@" "$(CZECH_IND)"

cze-kcor: $(CZECH_IND)
	@if [[ ! -s "$(CZECH_CUMD)" || ! -s "$(CZECH_RISK)" || "$(CZECH_IND)" -nt "$(CZECH_RISK)" || "$(SCRIPT)" -nt "$(CZECH_RISK)" ]]; then \
	  $(RUN) kcor --cutoff-start 2021-06-01 --cutoff-until 2024-05-01 --ages "$(AGES)" \
	    --age-reference 2024-09-02 \
	    --progress-total $(CZECH_POPULATION_ROWS) \
	    --spread-weekly-dates "$(CZECH_WEEKLY_DATE_SEED)" \
	    --risk-output "$(CZECH_RISK)" --output "$(CZECH_CUMD)" "$(CZECH_IND)"; \
	fi

cze-gamma: cze-kcor
	@if [[ ! -s "$(CZECH_GAMMA_PARAMS)" || ! -s "$(CZECH_GAMMA_SERIES)" || "$(CZECH_RISK)" -nt "$(CZECH_GAMMA_PARAMS)" || "$(GAMMA_SCRIPT)" -nt "$(CZECH_GAMMA_PARAMS)" ]]; then \
	$(RUBY) $(GAMMA_SCRIPT) --quiet-start 2022-W24 --quiet-end 2024-W16 \
	  --output "$(CZECH_GAMMA_PARAMS)" --series-output "$(CZECH_GAMMA_SERIES)" "$(CZECH_RISK)"; \
	fi

# 日本語: 生成済みの週単位匿名化INDを検査し、ElasticSearch投入用の入力を固定する。
# English: Validate the generated weekly-anonymized IND files used for Elasticsearch import.
indiv-check:
	@test -s "$(INDIV_MAPPING)"
	@test $(words $(INDIV_FILES)) -eq 8
	@for f in $(INDIV_FILES); do head -1 "$$f" | grep -q 'vbirthday' || { echo "missing vbirthday: $$f"; exit 1; }; done
	@wc -l $(INDIV_FILES)

# 日本語: 実行時に index を置換して公開 alias はサーバ側で indiv に向ける。
# English: Replace the versioned index at import time; the server publishes it through alias indiv.
indiv: indiv-check
	$(RUBY) ./import_indiv.rb --index "$(INDIV_INDEX)" --mapping "$(INDIV_MAPPING)" --replace $(INDIV_FILES)

# 日本語: 本番ではscpで再転送せず、公開済み圧縮CSVを展開してLogstashに読ませる。
# English: Production imports expand the already-published compressed CSVs and feed them to Logstash.
indiv-logstash-input:
	@echo "Logstash input directory: $(INDIV_PUBLIC_DIR)"
	@echo "Logstash config: $(INDIV_LOGSTASH_CONF)"

# 日本語: 生成物を圧縮し、公開ディレクトリへ差分転送する。ElasticSearch投入はサーバ側Logstashで行う。
# English: Compress generated files and transfer only changed files; server-side Logstash imports them.
publish-kkcor: indiv-check
	@mkdir -p /tmp/mstats-kkcor-upload
	@for f in $(INDIV_FILES) $(INDIVDTH_FILE); do xz -c "$$f" > "/tmp/mstats-kkcor-upload/$$(basename "$$f").xz"; done
	scp -p /tmp/mstats-kkcor-upload/*.xz $(KKCOR_HOST):$(KKCOR_DIR)/

indivdth:
	@test -s "$(INDIVDTH_FILE)"
	@echo "$(INDIVDTH_INDEX): $(INDIVDTH_FILE)"

# 日本語: 自治体ごとの差だけをここで宣言し、生成手順は共通化する。
# English: Declare only municipality-specific differences here and share the generation procedure.
define municipality
.PHONY: $(1)
$(1):
	@mkdir -p "$(OUT_DIR)" "$(OUT_DIR)/timings"
	@start=$$$$(date +%s); \
	inputs=($(4)); headers="$(5)"; opts=($(3)); \
	needs() { \
	  output="$$$$1"; \
	  [[ "$(FORCE)" == 1 || ! -s "$$$$output" || "$(SCRIPT)" -nt "$$$$output" || "$(lastword $(MAKEFILE_LIST))" -nt "$$$$output" ]] && return 0; \
	  for input in $$$$inputs $$$${(s:,:)headers}; do [[ "$$$$input" -nt "$$$$output" ]] && return 0; done; \
	  return 1; \
	}; \
	anon="$(OUT_DIR)/$(2)_$(6).csv"; \
	if needs "$$$$anon"; then \
	  $(RUN) anonymize --headers "$$$$headers" $$$$opts --output "$$$$anon" $$$$inputs || exit $$$$?; \
	fi; \
	if [[ "$(7)" == yes ]] && needs "$(OUT_DIR)/$(2)_PY-ORG.csv"; then \
	  $(RUN) personyear --headers "$$$$headers" --steps 1,3,6,all --step-prefix org --ages "$(AGES)" $$$$opts --output "$(OUT_DIR)/$(2)_PY-ORG.csv" $$$$inputs || exit $$$$?; \
	fi; \
	if [[ "$(7)" == yes ]] && needs "$(OUT_DIR)/$(2)_PY-WKD-ORG.csv"; then \
	  $(RUN) afterdose --headers "$$$$headers" --weeks 1-99 --step-prefix org --ages 80+,all $$$$opts --output "$(OUT_DIR)/$(2)_PY-WKD-ORG.csv" $$$$inputs || exit $$$$?; \
	fi; \
	if [[ "$(7)" == yes ]] && needs "$(OUT_DIR)/$(2)_PY.csv"; then \
	  population=$$$$(( $$$$(wc -l < "$$$$anon") - 1 )); \
	  reference=$$$$(sed -n '2p' "$$$$anon" | cut -d, -f6); \
	  $(RUN) personyear --steps 1,3,6,all --ages "$(AGES)" --age-reference "$$$$reference" \
	    --progress-total "$$$$population" --spread-weekly-dates "$(WEEKLY_DATE_SEED)" \
	    --output "$(OUT_DIR)/$(2)_PY.csv" "$$$$anon" || exit $$$$?; \
	fi; \
	if [[ "$(7)" == yes ]] && needs "$(OUT_DIR)/$(2)_PY-WKD.csv"; then \
	  $(RUN) afterdose --weeks 1-99 --ages 80+,all --spread-weekly-dates "$(WEEKLY_DATE_SEED)" \
	    --output "$(OUT_DIR)/$(2)_PY-WKD.csv" "$$$$anon" || exit $$$$?; \
	fi; \
	if needs "$(OUT_DIR)/$(2)_CUMD-WK.csv"; then \
	  $(RUN) kcor --headers "$$$$headers" $$$$opts --output "$(OUT_DIR)/$(2)_CUMD-WK.csv" $$$$inputs || exit $$$$?; \
	fi; \
	if [[ "$(7)" == yes ]] && needs "$(OUT_DIR)/$(2)_CUMD-WK-G.csv"; then \
	  $(RUN) kcor --headers "$$$$headers" $$$$opts \
	    --risk-output "$(OUT_DIR)/$(2)_CUMD-WK-G.csv" $$$$inputs || exit $$$$?; \
	fi; \
	elapsed=$$$$(( $$$$(date +%s) - start )); \
	printf '%s\t%s\n' '$(1)' "$$$$elapsed" | tee "$(OUT_DIR)/timings/$(1).tsv"
endef

$(eval $(call municipality,jp132101,jp132101_Koganei-Tokyo-JP,--prohibit-reason-in,$(SRC_DIR)/jp132101_東京都小金井市-Koganei-Tokyo-JP_all.csv,$(SRC_DIR)/jp132101_東京都小金井市-Koganei-Tokyo-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp141500,jp141500_Sagamihara-Kanagawa-JP,--allow-dup-id,$(SRC_DIR)/jp141500_神奈川県相模原市-Sagamihara-Kanagawa-JP_all.csv $(SRC_DIR)/jp141500_神奈川県相模原市-Sagamihara-Kanagawa-JP_all-death.csv,$(SRC_DIR)/jp141500_神奈川県相模原市-Sagamihara-Kanagawa-JP_header.csv$$(comma)$(SRC_DIR)/jp141500_神奈川県相模原市-Sagamihara-Kanagawa-JP_header-death.csv,IND-WKA,yes))
$(eval $(call municipality,jp221309,jp221309_Hamamatsu-Shizuoka-JP,,$(SRC_DIR)/jp221309_静岡県浜松市-Hamamatsu-Shizuoka-JP_all.csv,$(SRC_DIR)/jp221309_静岡県浜松市-Hamamatsu-Shizuoka-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp222267,jp222267_Makinohara-Shizuoka-JP,,$(SRC_DIR)/jp222267_静岡県牧之原市-Makinohara-Shizuoka-JP_all.csv,$(SRC_DIR)/jp222267_静岡県牧之原市-Makinohara-Shizuoka-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp232068,jp232068_Kasugai-Aichi-JP,,$(SRC_DIR)/jp232068_愛知県春日井市-Kasugai-Aichi-JP_all.csv,$(SRC_DIR)/jp232068_愛知県春日井市-Kasugai-Aichi-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp232076,jp232076_Toyokawa-Aichi-JP,--allow-dup-id,$(SRC_DIR)/jp232076_愛知県豊川市-Toyokawa-Aichi-JP_all.csv,$(SRC_DIR)/jp232076_愛知県豊川市-Toyokawa-Aichi-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp271004,jp271004_Osaka-Osaka-JP,,$(SRC_DIR)/jp271004_大阪府大阪市-Osaka-Osaka-JP_all.csv $(SRC_DIR)/jp271004_大阪府大阪市-Osaka-Osaka-JP_all-death.csv,$(SRC_DIR)/jp271004_大阪府大阪市-Osaka-Osaka-JP_header.csv$$(comma)$(SRC_DIR)/jp271004_大阪府大阪市-Osaka-Osaka-JP_header-death.csv,DTH-WKA,no))
$(eval $(call municipality,jp442054,jp442054_Saiki-Oita-JP,,$(SRC_DIR)/jp442054_大分県佐伯市-Saiki-Oita-JP_all.csv,$(SRC_DIR)/jp442054_大分県佐伯市-Saiki-Oita-JP_header.csv,IND-WKA,yes))
