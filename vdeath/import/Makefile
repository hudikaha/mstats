SHELL := /bin/zsh
.SHELLFLAGS := -eu -c

SRC_DIR ?= /Users/magician/icloud/vdeath/src
CZECH_SRC_DIR ?= /Users/magician/work/vdeath-src/Czech
OUT_DIR ?= ../outputs
RUBY ?= ruby
SCRIPT := ./vdeathp.rb
RUN := $(RUBY) $(SCRIPT)
GAMMA_SCRIPT := ./kcor_gamma.rb
INDIV_INDEX ?= indiv20260816
INDIV_MAPPING := ../config/elasticsearch/$(INDIV_INDEX).json
FULL_NAMES := jp13210_Koganei-Tokyo-JP jp14150_Sagamihara-Kanagawa-JP \
  jp22130_Hamamatsu-Shizuoka-JP jp22226_Makinohara-Shizuoka-JP \
  jp23206_Kasugai-Aichi-JP jp23207_Toyokawa-Aichi-JP jp44205_Saiki-Oita-JP
INDIV_FILES := $(addprefix $(OUT_DIR)/,$(addsuffix _IND-WKA.csv,$(FULL_NAMES)))
INDIV_PUBLIC_DIR ?= /home/magician/fujikawa/pub/kkcor
INDIV_LOGSTASH_CONF ?= ../config/logstash/indiv.conf
KKCOR_HOST ?= fujikawa.org
KKCOR_DIR ?= /home/magician/fujikawa/pub/kkcor
INDIVDTH_INDEX ?= indivdth20260816
INDIVDTH_FILE := $(OUT_DIR)/jp27100_Osaka-Osaka-JP_DTH-WKA.csv
AGES := 00-09,10-19,20-29,30-39,40-49,50-59,60-69,70-79,80-89,90-99,100+,80+,all
CITIES := jp13210 jp14150 jp22130 jp22226 jp23206 jp23207 jp27100 jp44205
CZECH_INPUT := $(CZECH_SRC_DIR)/Otevrena-data-NR-26-30-COVID-19-prehled-populace-2024-01.csv
CZECH_HEADER := ./headers/czech-2024-01.csv
CZECH_NAME := cze_Czech-Republic
CZECH_PY := $(OUT_DIR)/$(CZECH_NAME)_PY.csv
PUBLIC_PY_FILES := $(CZECH_PY) $(addprefix $(OUT_DIR)/,$(addsuffix _PY.csv,$(FULL_NAMES)))
CZECH_AFTERDOSE := $(OUT_DIR)/$(CZECH_NAME)_PY-WKD.csv
CZECH_CUMD := $(OUT_DIR)/$(CZECH_NAME)_CUMD-WK.csv
CZECH_RISK := $(OUT_DIR)/$(CZECH_NAME)_CUMD-WK-G.csv
CZECH_GAMMA_PARAMS := $(OUT_DIR)/$(CZECH_NAME)_GAMMA-CONSTANT-PARAMS.csv
CZECH_GAMMA_SERIES := $(OUT_DIR)/$(CZECH_NAME)_GAMMA-CONSTANT-SERIES.csv
CZECH_WEEKLY_DATE_SEED ?= v1
CZECH_SOURCE_ROWS := 12597668
CZECH_POPULATION_ROWS := 10314685
WEEKLY_DATE_SEED ?= v1
CUMD_NAMES := cze_Czech-Republic \
  jp13210_Koganei-Tokyo-JP jp14150_Sagamihara-Kanagawa-JP \
  jp22130_Hamamatsu-Shizuoka-JP jp22226_Makinohara-Shizuoka-JP \
  jp23206_Kasugai-Aichi-JP jp23207_Toyokawa-Aichi-JP \
  jp27100_Osaka-Osaka-JP jp44205_Saiki-Oita-JP
CUMD_FILES := $(addprefix $(OUT_DIR)/,$(addsuffix _CUMD-WK.csv,$(CUMD_NAMES)))
CUMD_POP_FILES := $(filter-out $(OUT_DIR)/jp27100_Osaka-Osaka-JP_CUMD-WK.csv,$(CUMD_FILES))
CUMD_BACKUP_DIR ?= $(OUT_DIR)/cumd-wk-before-vdeathp
comma := ,
SERVER ?= fujikawa.org
SERVER_DIR ?= /home/magician/vdeath/migration-20260816
KCOR_INDEX ?= kcor20260816
KCOR_MAPPING := ../config/elasticsearch/$(KCOR_INDEX)-mapping.json
VDEATH_INDEX ?= vdeath20260816
VDEATH_MAPPING := ../config/elasticsearch/$(VDEATH_INDEX).json
VDEATH_FILES := $(CZECH_PY) $(CZECH_AFTERDOSE) \
  $(addprefix $(OUT_DIR)/,$(addsuffix _PY.csv,$(FULL_NAMES))) \
  $(addprefix $(OUT_DIR)/,$(addsuffix _PY-ORG.csv,$(FULL_NAMES))) \
  $(addprefix $(OUT_DIR)/,$(addsuffix _PY-WKD.csv,$(FULL_NAMES))) \
  $(addprefix $(OUT_DIR)/,$(addsuffix _PY-WKD-ORG.csv,$(FULL_NAMES)))
KCOR_FILES := $(CUMD_FILES)

.PHONY: all data-all cze cze-all cze-py cze-afterdose cze-kcor cze-gamma \
  cumd cumd-backup cumd-check cumd-compare cze-cumd-direct publish-cumd \
  indiv-check public-py-check indiv indivdth publish-kkcor generated-check upload-index-inputs \
  import-new-indices import-indiv-indices check-new-indices switch-index-aliases $(CITIES) $(addsuffix -cumd-direct,$(CITIES))
all: $(CITIES)
data-all: cze-all $(CITIES)

# 日本語: チェコ公式週次個票から各集計を直接生成し、公開用匿名化個票は作らない。
# English: Generate aggregates directly from Czech official weekly records; do not create a public anonymized copy.
cze: cze-py cze-kcor cze-gamma
cze-all: cze cze-afterdose
cze-py:
	@if [[ "$(FORCE)" == 1 || ! -s "$(CZECH_PY)" || "$(CZECH_INPUT)" -nt "$(CZECH_PY)" || "$(CZECH_HEADER)" -nt "$(CZECH_PY)" || "$(SCRIPT)" -nt "$(CZECH_PY)" ]]; then \
	  $(RUN) personyear --headers "$(CZECH_HEADER)" --skip-source-header --first-infection-only --iso-week-dates \
	    --loc cze --area "Czech Republic" --areaj "チェコ" --steps 1,3,6,all --ages "$(AGES)" \
	    --start 2021-02-01 --until 2024-09-02 --age-reference 2024-09-02 \
	    --progress-total $(CZECH_SOURCE_ROWS) --spread-weekly-dates "$(CZECH_WEEKLY_DATE_SEED)" \
	    --output "$(CZECH_PY)" "$(CZECH_INPUT)"; \
	fi
cze-afterdose:
	@if [[ "$(FORCE)" == 1 || ! -s "$(CZECH_AFTERDOSE)" || "$(CZECH_INPUT)" -nt "$(CZECH_AFTERDOSE)" || "$(CZECH_HEADER)" -nt "$(CZECH_AFTERDOSE)" || "$(SCRIPT)" -nt "$(CZECH_AFTERDOSE)" ]]; then \
	  $(RUN) afterdose --headers "$(CZECH_HEADER)" --skip-source-header --first-infection-only --iso-week-dates \
	    --loc cze --area "Czech Republic" --areaj "チェコ" --weeks 1-99 --ages 80+,all \
	    --until 2024-09-02 --age-reference 2024-09-02 --progress-total $(CZECH_SOURCE_ROWS) \
	    --spread-weekly-dates "$(CZECH_WEEKLY_DATE_SEED)" \
	    --output "$(CZECH_AFTERDOSE)" "$(CZECH_INPUT)"; \
	fi

# 日本語: チェコ公式CSVからCUMD-WKだけを直接再生成する。
# English: Regenerate only Czech CUMD-WK directly from the official CSV.
cze-cumd-direct:
	$(RUN) kcor --headers "$(CZECH_HEADER)" --skip-source-header --first-infection-only --iso-week-dates \
	  --loc cze --area "Czech Republic" --areaj "チェコ" \
	  --cutoff-start 2021-06-01 --cutoff-until 2024-05-01 --ages "$(AGES)" \
	  --age-reference 2024-09-02 --progress-total $(CZECH_SOURCE_ROWS) \
	  --spread-weekly-dates "$(CZECH_WEEKLY_DATE_SEED)" \
	  --output "$(CZECH_CUMD)" "$(CZECH_INPUT)"

cze-kcor:
	@if [[ "$(FORCE)" == 1 || ! -s "$(CZECH_CUMD)" || ! -s "$(CZECH_RISK)" || "$(CZECH_INPUT)" -nt "$(CZECH_RISK)" || "$(SCRIPT)" -nt "$(CZECH_RISK)" ]]; then \
	  $(RUN) kcor --headers "$(CZECH_HEADER)" --skip-source-header --first-infection-only --iso-week-dates \
	    --loc cze --area "Czech Republic" --areaj "チェコ" \
	    --cutoff-start 2021-06-01 --cutoff-until 2024-05-01 --ages "$(AGES)" \
	    --age-reference 2024-09-02 \
	    --progress-total $(CZECH_SOURCE_ROWS) \
	    --spread-weekly-dates "$(CZECH_WEEKLY_DATE_SEED)" \
	    --risk-output "$(CZECH_RISK)" --output "$(CZECH_CUMD)" "$(CZECH_INPUT)"; \
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
	@test $(words $(INDIV_FILES)) -eq 7
	@for f in $(INDIV_FILES); do head -1 "$$f" | grep -q 'vbirthday' || { echo "missing vbirthday: $$f"; exit 1; }; done
	@wc -l $(INDIV_FILES)

# 日本語: 公開する国・自治体別PYだけを検査し、ORG・WKD系列を混入させない。
# English: Validate only public country/municipality PY files; exclude ORG and WKD series.
public-py-check:
	@test $(words $(PUBLIC_PY_FILES)) -eq 8
	@for f in $(PUBLIC_PY_FILES); do \
	  test -s "$$f" || { echo "Missing: $$f"; exit 1; }; \
	  test "$$(head -1 "$$f")" = 'id,loc,area,areaj,step,period,age,dose,lives,persondays,deaths,lb0,ub0,rr0,lbm,ubm,mortality' || \
	    { echo "Unexpected header: $$f"; exit 1; }; \
	done
	@wc -l $(PUBLIC_PY_FILES)

# 日本語: 実行時に index を置換して公開 alias はサーバ側で indiv に向ける。
# English: Replace the versioned index at import time; the server publishes it through alias indiv.
indiv: indiv-check
	$(RUBY) ./import_indiv.rb --index "$(INDIV_INDEX)" --mapping "$(INDIV_MAPPING)" --replace $(INDIV_FILES)

# 日本語: 本番ではscpで再転送せず、公開済み圧縮CSVを展開してLogstashに読ませる。
# English: Production imports expand the already-published compressed CSVs and feed them to Logstash.
indiv-logstash-input:
	@echo "Logstash input directory: $(INDIV_PUBLIC_DIR)"
	@echo "Logstash config: $(INDIV_LOGSTASH_CONF)"

# 日本語: 公開用の国・自治体別PYと匿名個票を専用一時directoryで圧縮して転送する。
# English: Compress and publish country/municipality PY files and anonymized records from a dedicated temporary directory.
publish-kkcor: indiv-check public-py-check
	@upload_dir=$$(mktemp -d /tmp/mstats-kkcor-upload.XXXXXX); \
	trap 'rm -r -- "$$upload_dir"' EXIT; \
	for f in $(PUBLIC_PY_FILES) $(INDIV_FILES) $(INDIVDTH_FILE); do \
	  xz -c "$$f" > "$$upload_dir/$$(basename "$$f").xz"; \
	done; \
	scp -p "$$upload_dir"/*.xz "$(KKCOR_HOST):$(KKCOR_DIR)/"

# 日本語: 現在のCUMD-WKを比較用directoryへ一度だけ退避する。
# English: Preserve the current CUMD-WK files once in a comparison directory.
cumd-backup:
	@test $(words $(CUMD_FILES)) -eq 9
	@test ! -e "$(CUMD_BACKUP_DIR)" || { echo "Backup already exists: $(CUMD_BACKUP_DIR)"; exit 1; }
	@mkdir -p "$(CUMD_BACKUP_DIR)"
	@cp -p $(CUMD_FILES) "$(CUMD_BACKUP_DIR)/"
	@echo "Backed up 9 CUMD-WK files to $(CUMD_BACKUP_DIR)"

# 日本語: CUMD-WKだけをvdeathp.rbから直接全系列再生成する。
# English: Regenerate every CUMD-WK directly with vdeathp.rb and no unrelated outputs.
cumd: cze-cumd-direct $(addsuffix -cumd-direct,$(CITIES))

cumd-check:
	@test $(words $(CUMD_FILES)) -eq 9
	@for f in $(CUMD_FILES); do test -s "$$f" || { echo "Missing: $$f"; exit 1; }; done
	@for f in $(CUMD_POP_FILES); do \
	  test "$$(head -1 "$$f")" = 'id,loc,area,areaj,cutoff,cweek,date,age,dose,deaths,pop' || \
	    { echo "Unexpected header: $$f"; exit 1; }; \
	done
	@test "$$(head -1 "$(OUT_DIR)/jp27100_Osaka-Osaka-JP_CUMD-WK.csv")" = \
	  'id,loc,area,areaj,cutoff,cweek,date,age,dose,deaths'
	@wc -l $(CUMD_FILES)

cumd-compare: cumd-check
	@test -d "$(CUMD_BACKUP_DIR)" || { echo "Missing backup: $(CUMD_BACKUP_DIR)"; exit 1; }
	@different=0; \
	for f in $(CUMD_FILES); do \
	  old="$(CUMD_BACKUP_DIR)/$$(basename "$$f")"; \
	  test -s "$$old" || { echo "Missing backup: $$old"; exit 1; }; \
	  if cmp -s "$$old" "$$f"; then \
	    echo "Identical: $$(basename "$$f")"; \
	  else \
	    echo "Different: $$(basename "$$f")"; \
	    different=1; \
	  fi; \
	done; \
	exit $$different

# 日本語: 検査済みCUMD-WKだけを専用一時directoryで圧縮して公開する。
# English: Compress and publish only validated CUMD-WK files from a dedicated temporary directory.
publish-cumd: cumd-check
	@upload_dir=$$(mktemp -d /tmp/mstats-cumd-upload.XXXXXX); \
	trap 'rm -r -- "$$upload_dir"' EXIT; \
	for f in $(CUMD_FILES); do xz -c "$$f" > "$$upload_dir/$$(basename "$$f").xz"; done; \
	scp -p "$$upload_dir"/*.xz "$(KKCOR_HOST):$(KKCOR_DIR)/"

indivdth:
	@test -s "$(INDIVDTH_FILE)"
	@echo "$(INDIVDTH_INDEX): $(INDIVDTH_FILE)"

# 日本語: Makeで再生成した全系列だけを新規index投入対象として検査する。
# English: Validate only the series regenerated by Make before importing new indices.
generated-check: cumd-check indiv-check
	@test -s "$(KCOR_MAPPING)"
	@test -s "$(VDEATH_MAPPING)"
	@test -s "$(INDIV_MAPPING)"
	@test $(words $(VDEATH_FILES)) -eq 30
	@for f in $(VDEATH_FILES); do test "$$(head -1 "$$f")" = 'id,loc,area,areaj,step,period,age,dose,lives,persondays,deaths,lb0,ub0,rr0,lbm,ubm,mortality' || { echo "Unexpected header: $$f"; exit 1; }; done
	@for f in $(INDIV_FILES) $(INDIVDTH_FILE); do head -1 "$$f" | grep -q '^id,loc,area,areaj,' || { echo "Unexpected header: $$f"; exit 1; }; done
	@! rg -n '^([^,]*,)?jp[0-9]{6},' $(KCOR_FILES) $(VDEATH_FILES) $(INDIV_FILES) $(INDIVDTH_FILE)
	@wc -l $(KCOR_FILES) $(VDEATH_FILES) $(INDIV_FILES) $(INDIVDTH_FILE)

# 日本語: 新規物理index用のscript・mapping・CSVをserverの専用directoryへ転送する。
# English: Upload scripts, mappings, and CSVs to a dedicated server directory for new physical indices.
upload-index-inputs: generated-check
	@ssh "$(SERVER)" 'mkdir -p "$(SERVER_DIR)/data" "$(SERVER_DIR)/config"'
	@rsync -a --progress ./import_py.rb ./import_indiv.rb "$(SERVER):$(SERVER_DIR)/"
	@rsync -a --progress "$(KCOR_MAPPING)" "$(VDEATH_MAPPING)" "$(INDIV_MAPPING)" "$(SERVER):$(SERVER_DIR)/config/"
	@rsync -a --progress $(KCOR_FILES) $(VDEATH_FILES) $(INDIV_FILES) $(INDIVDTH_FILE) "$(SERVER):$(SERVER_DIR)/data/"

# 日本語: 各系列を空の新規物理indexへ投入し、系列ごとの秒数を記録する。
# English: Import each series into empty versioned indices and record elapsed seconds by series.
import-new-indices: upload-index-inputs
	@ssh "$(SERVER)" 'set -eu; cd "$(SERVER_DIR)"; rm -f timings.tsv; \
	  start=$$(date +%s); ruby ./import_py.rb --replace --index "$(KCOR_INDEX)" --mapping "config/$$(basename "$(KCOR_MAPPING)")" --no-doc-id --integer-fields dose,deaths,pop data/*_CUMD-WK.csv; printf "kcor\\t%s\\n" "$$(($$(date +%s)-start))" >> timings.tsv; \
	  start=$$(date +%s); ruby ./import_py.rb --replace --index "$(VDEATH_INDEX)" --mapping "config/$$(basename "$(VDEATH_MAPPING)")" data/*_PY.csv data/*_PY-ORG.csv data/*_PY-WKD.csv data/*_PY-WKD-ORG.csv; printf "vdeath\\t%s\\n" "$$(($$(date +%s)-start))" >> timings.tsv; \
	  start=$$(date +%s); ruby ./import_indiv.rb --replace --index "$(INDIV_INDEX)" --mapping "config/$$(basename "$(INDIV_MAPPING)")" data/*_IND-WKA.csv; printf "indiv\\t%s\\n" "$$(($$(date +%s)-start))" >> timings.tsv; \
	  start=$$(date +%s); ruby ./import_indiv.rb --replace --index "$(INDIVDTH_INDEX)" --mapping "config/$$(basename "$(INDIV_MAPPING)")" data/*_DTH-WKA.csv; printf "indivdth\\t%s\\n" "$$(($$(date +%s)-start))" >> timings.tsv; cat timings.tsv'

# 日本語: IND投入だけを安全に再実行し、完了済みKCOR・vdeathは作り直さない。
# English: Retry only IND imports without rebuilding completed KCOR and vdeath indices.
import-indiv-indices: upload-index-inputs
	@ssh "$(SERVER)" 'set -eu; cd "$(SERVER_DIR)"; \
	  start=$$(date +%s); ruby ./import_indiv.rb --replace --index "$(INDIV_INDEX)" --mapping "config/$$(basename "$(INDIV_MAPPING)")" data/*_IND-WKA.csv; printf "indiv\\t%s\\n" "$$(($$(date +%s)-start))" >> timings.tsv; \
	  start=$$(date +%s); ruby ./import_indiv.rb --replace --index "$(INDIVDTH_INDEX)" --mapping "config/$$(basename "$(INDIV_MAPPING)")" data/*_DTH-WKA.csv; printf "indivdth\\t%s\\n" "$$(($$(date +%s)-start))" >> timings.tsv; tail -2 timings.tsv'

# 日本語: 件数、loc field、6桁自治体codeの不存在をalias切替前に検査する。
# English: Check counts, loc fields, and absence of six-digit municipality codes before alias switching.
check-new-indices:
	@ssh "$(SERVER)" 'cred=$$HOME/.config/mstats/espass.txt; u=$$(cut -d: -f1 "$$cred"); p=$$(cut -d: -f2- "$$cred"); \
	  for idx in $(KCOR_INDEX) $(VDEATH_INDEX) $(INDIV_INDEX) $(INDIVDTH_INDEX); do \
	    curl -fsS -u "$$u:$$p" -H "Content-Type: application/json" "http://127.0.0.1:9200/$$idx/_count"; echo " $$idx"; \
	    response=$$(curl -fsS -u "$$u:$$p" -H "Content-Type: application/json" "http://127.0.0.1:9200/$$idx/_count" -d '\''{"query":{"bool":{"must_not":{"exists":{"field":"loc"}}}}}'\''); [[ "$$response" == *'\''"count":0'\''* ]] || exit 1; \
	    response=$$(curl -fsS -u "$$u:$$p" -H "Content-Type: application/json" "http://127.0.0.1:9200/$$idx/_count" -d '\''{"query":{"regexp":{"loc":"jp[0-9]{6}"}}}'\''); [[ "$$response" == *'\''"count":0'\''* ]] || exit 1; \
	  done; exit 0'

# 日本語: 検査済み物理indexへ4つの公開aliasを一回のcluster operationで切り替える。
# English: Switch four public aliases to validated physical indices in one cluster operation.
switch-index-aliases: check-new-indices
	@ssh "$(SERVER)" 'cred=$$HOME/.config/mstats/espass.txt; u=$$(cut -d: -f1 "$$cred"); p=$$(cut -d: -f2- "$$cred"); \
	  curl -fsS -u "$$u:$$p" -H "Content-Type: application/json" -X POST "http://127.0.0.1:9200/_aliases" -d '\''{"actions":[{"remove":{"index":"*","alias":"kcor"}},{"add":{"index":"$(KCOR_INDEX)","alias":"kcor"}},{"remove":{"index":"*","alias":"vdeath"}},{"add":{"index":"$(VDEATH_INDEX)","alias":"vdeath"}},{"remove":{"index":"*","alias":"indiv"}},{"add":{"index":"$(INDIV_INDEX)","alias":"indiv"}},{"remove":{"index":"*","alias":"indivdth"}},{"add":{"index":"$(INDIVDTH_INDEX)","alias":"indivdth"}}]}'\''; echo'

# 日本語: 自治体ごとの差だけをここで宣言し、生成手順は共通化する。
# English: Declare only municipality-specific differences here and share the generation procedure.
define municipality
.PHONY: $(1) $(1)-cumd-direct
$(1)-cumd-direct:
	@mkdir -p "$(OUT_DIR)"
	$(RUN) kcor $(if $(filter yes,$(7)),,--death-only) --headers "$(5)" $(3) \
	  --output "$(OUT_DIR)/$(2)_CUMD-WK.csv" $(4)

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
	  $(RUN) kcor $(if $(filter yes,$(7)),,--death-only) --headers "$$$$headers" $$$$opts \
	    --output "$(OUT_DIR)/$(2)_CUMD-WK.csv" $$$$inputs || exit $$$$?; \
	fi; \
	if [[ "$(7)" == yes ]] && needs "$(OUT_DIR)/$(2)_CUMD-WK-G.csv"; then \
	  $(RUN) kcor --headers "$$$$headers" $$$$opts \
	    --risk-output "$(OUT_DIR)/$(2)_CUMD-WK-G.csv" $$$$inputs || exit $$$$?; \
	fi; \
	elapsed=$$$$(( $$$$(date +%s) - start )); \
	printf '%s\t%s\n' '$(1)' "$$$$elapsed" | tee "$(OUT_DIR)/timings/$(1).tsv"
endef

$(eval $(call municipality,jp13210,jp13210_Koganei-Tokyo-JP,--prohibit-reason-in,$(SRC_DIR)/jp132101_東京都小金井市-Koganei-Tokyo-JP_all.csv,$(SRC_DIR)/jp132101_東京都小金井市-Koganei-Tokyo-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp14150,jp14150_Sagamihara-Kanagawa-JP,--allow-dup-id,$(SRC_DIR)/jp141500_神奈川県相模原市-Sagamihara-Kanagawa-JP_all.csv $(SRC_DIR)/jp141500_神奈川県相模原市-Sagamihara-Kanagawa-JP_all-death.csv,$(SRC_DIR)/jp141500_神奈川県相模原市-Sagamihara-Kanagawa-JP_header.csv$$(comma)$(SRC_DIR)/jp141500_神奈川県相模原市-Sagamihara-Kanagawa-JP_header-death.csv,IND-WKA,yes))
$(eval $(call municipality,jp22130,jp22130_Hamamatsu-Shizuoka-JP,,$(SRC_DIR)/jp221309_静岡県浜松市-Hamamatsu-Shizuoka-JP_all.csv,$(SRC_DIR)/jp221309_静岡県浜松市-Hamamatsu-Shizuoka-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp22226,jp22226_Makinohara-Shizuoka-JP,,$(SRC_DIR)/jp222267_静岡県牧之原市-Makinohara-Shizuoka-JP_all.csv,$(SRC_DIR)/jp222267_静岡県牧之原市-Makinohara-Shizuoka-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp23206,jp23206_Kasugai-Aichi-JP,,$(SRC_DIR)/jp232068_愛知県春日井市-Kasugai-Aichi-JP_all.csv,$(SRC_DIR)/jp232068_愛知県春日井市-Kasugai-Aichi-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp23207,jp23207_Toyokawa-Aichi-JP,--allow-dup-id,$(SRC_DIR)/jp232076_愛知県豊川市-Toyokawa-Aichi-JP_all.csv,$(SRC_DIR)/jp232076_愛知県豊川市-Toyokawa-Aichi-JP_header.csv,IND-WKA,yes))
$(eval $(call municipality,jp27100,jp27100_Osaka-Osaka-JP,,$(SRC_DIR)/jp271004_大阪府大阪市-Osaka-Osaka-JP_all.csv $(SRC_DIR)/jp271004_大阪府大阪市-Osaka-Osaka-JP_all-death.csv,$(SRC_DIR)/jp271004_大阪府大阪市-Osaka-Osaka-JP_header.csv$$(comma)$(SRC_DIR)/jp271004_大阪府大阪市-Osaka-Osaka-JP_header-death.csv,DTH-WKA,no))
$(eval $(call municipality,jp44205,jp44205_Saiki-Oita-JP,,$(SRC_DIR)/jp442054_大分県佐伯市-Saiki-Oita-JP_all.csv,$(SRC_DIR)/jp442054_大分県佐伯市-Saiki-Oita-JP_header.csv,IND-WKA,yes))
