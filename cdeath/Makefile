SHELL := /bin/zsh
.SHELLFLAGS := -eu -o pipefail -c

# Target flow
#
#   make (default) -> help
#   check          -> source-month checks -> temporary pop/death conversion -> CSV checks
#   csv            -> source-month checks -> manifest comparison
#                     -> changed: timestamped pop/monthly-death/weekly-death CSV creation and checks
#                     -> unchanged: print the next months and e-Stat URLs
#   fetch          -> fetch-pop -> fetch-death
#   fetch-pop      -> Codex searches e-Stat -> saves new population source CSVs
#   fetch-death    -> Codex searches e-Stat -> saves new cause-of-death source CSVs
#   cod, codtr     -> csv
#                     -> CSV created: upload -> logstash
#                     -> no CSV created: stop after the URL guidance
#   all            -> fetch -> cod
#   upload         -> scp latest CSVs -> update server symlinks
#   logstash       -> stop service -> run server-side mstats2026.conf once

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
POP_ARCHIVE_DIR ?= $(ROOT)/src/popjp
DCAUSE_SOURCE_DIR ?= $(ROOT)/src/causejp
DCAUSE_CFM_DIR ?= $(ROOT)/src/causejp-cfm
DCAUSE_CFM_YEARLY_DIR ?= $(ROOT)/src/causejp-cfm-yearly
POP_CFM_LEGACY_DIR ?= $(ROOT)/src/popjp-cfm-legacy
STMF_DIR ?= $(ROOT)/src/stmf
STMF_SOURCE ?= $(STMF_DIR)/stmf.csv
US_MORTYEAR_SOURCE ?= $(ROOT)/import/us-mortyear-series.csv
JP_INFANT_DIR ?= $(ROOT)/src/infantjp
JP_INFANT_SOURCE ?= $(JP_INFANT_DIR)/2024-infant-6-1.csv
JP_PERINATAL_SOURCE ?= $(JP_INFANT_DIR)/2024-perinatal-8-1.csv
WPP_DIR ?= $(ROOT)/src/wpp
WPP_BASE_URL := https://population.un.org/wpp/assets/Excel%20Files/1_Indicator%20(Standard)/CSV_FILES
WPP_DEMOGRAPHIC := $(WPP_DIR)/WPP2024_Demographic_Indicators_Medium.csv.gz
WPP_DEATH_HIST := $(WPP_DIR)/WPP2024_DeathsBySingleAgeSex_Medium_1950-2023.csv.gz
WPP_DEATH_PROJ := $(WPP_DIR)/WPP2024_DeathsBySingleAgeSex_Medium_2024-2100.csv.gz
WPP_EXPOSURE_HIST := $(WPP_DIR)/WPP2024_PopulationExposureBySingleAgeSex_Medium_1950-2023.csv.gz
WPP_EXPOSURE_PROJ := $(WPP_DIR)/WPP2024_PopulationExposureBySingleAgeSex_Medium_2024-2100.csv.gz
OECD_DIR ?= $(ROOT)/src/oecd
OECD_MIM_SOURCE ?= $(OECD_DIR)/maternal-infant-mortality.csv
OECD_MIM_URL := https://sdmx.oecd.org/public/rest/v1/data/OECD.ELS.HD,DSD_HEALTH_STAT@DF_MIM,1.1/.A.INM+PERM..........?startPeriod=2000&dimensionAtObservation=AllDimensions
UN_MONTHLY_DIR ?= $(ROOT)/src/un
UN_MONTHLY_ARCHIVE ?= $(UN_MONTHLY_DIR)/un-monthly-mortality.zip
UN_MONTHLY_SOURCE ?= $(UN_MONTHLY_DIR)/UNdata_Export_mortality.csv
UN_MONTHLY_URL := https://data.un.org/Handlers/DownloadHandler.ashx?DataFilter=tableCode%3A65&DataMartId=POP&Format=csv
EXDEATHS_DIR ?= $(ROOT)/src/exdeaths
EXDEATHS_ALL ?= $(EXDEATHS_DIR)/Observed.csv
EXDEATHS_CAUSE_ARCHIVE ?= $(EXDEATHS_DIR)/Observed.csv.zip
EXDEATHS_CAUSE_DIR ?= $(EXDEATHS_DIR)/cause
EXDEATHS_URL := https://exdeaths-japan.org/data/Observed.csv
EXDEATHS_CAUSE_URL := https://exdeaths-japan.org/data/Observed.csv.zip
DATA_DIR ?= $(ROOT)/out
STATE_DIR ?= $(ROOT)/tmp/make

POP_URL := https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0
DCAUSE_URL := https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0

SERVER ?= fujikawa.org
SERVER_MSTATS_DIR ?= mstats
SERVER_WEB_DIR ?= fujikawa/covid19
YEARLY_INDEX ?= mstats20260816
LOGSTASH ?= /usr/share/logstash/bin/logstash
CODEX ?= codex

.PHONY: help all location-config fetch fetch-pop fetch-death fetch-stmf fetch-exdeaths fetch-wpp fetch-un-monthly check csv schema-csv mort-csv stmf-csv exdeaths-sample-csv exdeaths-csv confirmed-sample-csv confirmed-csv canonical-weekly-csv \
  yearly-csv jp-yearly-csv jp-infant-yearly-csv us-yearly-csv oecd-infant-yearly-csv wpp-yearly-csv un-monthly-csv validate-csv upload-official \
  upload-hmd upload-wpp upload-oecd upload-un-monthly upload-confirmed upload-yearly logstash-official logstash-hmd logstash-wpp logstash-oecd logstash-un-monthly logstash-confirmed \
  upload-exdeaths-sample upload-exdeaths upload-mstats-all check-latest-id-collisions reset-mstats-index check-mstats-index switch-mstats-alias upload logstash logstash-exdeaths-sample logstash-exdeaths cod codtr

define VALIDATE_MONTHS
validate_months() { \
  local label=$$1; shift; local files=("$$@") names=(); \
  local first='' last='' previous=-1 count=0 name year month serial file; \
	  for file in "$${files[@]}"; do \
	    [[ -s $$file ]] || { echo "empty source file: $$file"; return 1; }; \
	    names+=("$${file:t:r}"); \
	  done; \
	  names=("$${(@on)names}"); \
	  for name in "$${names[@]}"; do \
	    [[ $$name == <->-<-> ]] || { echo "unexpected source name: $$name"; return 1; }; \
    year=$${name%-*}; month=$${name#*-}; serial=$$(( year * 12 + month )); \
    (( previous < 0 || serial == previous + 1 )) || { echo "missing or duplicate $$label month before $$name"; return 1; }; \
    [[ -n $$first ]] || first=$$name; last=$$name; previous=$$serial; (( count += 1 )); \
  done; \
  echo "$$label source months: $$count ($$first..$$last)"; \
}
endef

define VALIDATE_CSV
validate_csv() { \
  local category=$$1 file=$$2 header duplicates rows periods first last; \
  header=$$(head -1 "$$file"); \
  [[ $$header == id,loc,area,areaj,yearmonth,category,*age_junior ]] || { echo "wrong mstats2026 header: $$file"; return 1; }; \
  rows=$$(( $$(wc -l < "$$file") - 1 )); (( rows > 0 )) || { echo "no data rows: $$file"; return 1; }; \
  duplicates=$$(tail -n +2 "$$file" | cut -d, -f1 | LC_ALL=C sort | uniq -d); \
  [[ -z $$duplicates ]] || { echo "duplicate ids: $$file"; return 1; }; \
  awk -F, -v category="$$category" 'NR > 1 && $$6 != category { exit 1 }' "$$file" || { echo "wrong category: $$file"; return 1; }; \
  ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$file" || return 1; \
  periods=$$(tail -n +2 "$$file" | cut -d, -f5 | LC_ALL=C sort -u); \
  first=$$(print -r -- "$$periods" | head -1); last=$$(print -r -- "$$periods" | tail -1); \
  echo "$$category: rows=$$rows periods=$$(print -r -- "$$periods" | wc -l | tr -d ' ') ($$first..$$last)"; \
}
endef

define VALIDATE_WEEKLY_CSV
validate_weekly_csv() { \
  local file=$$1 header summary; \
  header=$$(head -1 "$$file"); \
  [[ $$header == id,loc,area,areaj,yearweek,category,*age_50_64 ]] || { echo "wrong weekly mstats2026 header: $$file"; return 1; }; \
  summary=$$(awk -F, 'NR == 1 { next } \
    seen[$$1]++ { duplicate = $$1; exit } \
    $$6 != "death" { wrong_category = $$6; exit } \
    { rows += 1; if (!period[$$5]++) { periods += 1; if (first == "" || $$5 < first) first = $$5; if ($$5 > last) last = $$5 } } \
    END { \
      if (duplicate != "") { print "duplicate weekly id: " duplicate > "/dev/stderr"; exit 1 } \
      if (wrong_category != "") { print "wrong weekly category: " wrong_category > "/dev/stderr"; exit 1 } \
      if (rows == 0) { print "no weekly data rows" > "/dev/stderr"; exit 1 } \
      printf "weekly death: rows=%d periods=%d (%s..%s)", rows, periods, first, last \
    }' "$$file") || return 1; \
  echo "$$summary"; \
}
endef

help:
	@echo 'make location-config locに対応する日英地域名とmortyear用地域分類を再生成'
	@echo 'make check    原CSVの月抜けと変換結果を検証'
	@echo 'make fetch    Codexで人口・死因の次月公開確認と取得（既存CSVは検証しない）'
	@echo 'make fetch-pop   Codexで人口の新規原CSVを取得'
	@echo 'make fetch-death Codexで死因の新規原CSVを取得'
	@echo 'make fetch-stmf HMD認証情報を環境変数から読みSTMF pooled CSVを取得'
	@echo 'make fetch-wpp UN WPP 2024の人口・単年齢死亡・population exposureを取得'
	@echo 'make fetch-un-monthly UNdataの月別死亡数を取得'
	@echo 'make un-monthly-csv UN月別死亡数と年率換算死亡率の投入前CSVを作成'
	@echo 'make all      Codexで取得後、CSV生成・必要時のみ投入'
	@echo 'make csv      原CSV更新時に月次・週次の日時付き累積CSVを同時生成'
	@echo 'make schema-csv data形式変更時に人口・月次死亡・週次死亡CSVを無条件で再生成'
	@echo 'make confirmed-csv 1999年以降の日本確定数から月次・週次・年次CSVを生成（投入しない）'
	@echo 'make canonical-weekly-csv 確定月次を優先し、その後を概数・速報で補う週次CSVを生成'
	@echo 'make confirmed-sample-csv 1999年だけで確定人口・年次死亡のfieldとIDを短縮検査'
	@echo 'make mort-csv 最新の月次CSVからmort.rb用週次CSVを生成（投入しない）'
	@echo 'make stmf-csv STMF pooled CSVをmstats2026週次CSVへ変換（投入しない）'
	@echo 'make fetch-exdeaths 超過死亡dashboardの全死因・死因別CSVを取得'
	@echo 'make exdeaths-sample-csv 全国7系列の短縮検査CSVを生成（投入しない）'
	@echo 'make exdeaths-csv 全国・47都道府県の7系列CSVを生成（投入しない）'
	@echo 'make yearly-csv 最新の日本月次CSVから年次CSVを生成（投入しない）'
	@echo 'make jp-yearly-csv 最新の日本月次CSVから年次CSVを生成（投入しない）'
	@echo 'make jp-infant-yearly-csv 日本の乳児・周産期死亡の年次CSVを生成（投入しない）'
	@echo 'make us-yearly-csv 米国の出生・乳児死亡・周産期死亡年次CSVを生成（投入しない）'
	@echo 'make oecd-infant-yearly-csv OECD率とWPP出生数から各国の近似年次CSVを生成（投入しない）'
	@echo 'make wpp-yearly-csv UN WPPの人口・死亡・粗死亡率・WHO標準ASRを生成（投入しない）'
	@echo 'make upload-official 各国公式CSVをserverへ送る（投入しない）'
	@echo 'make upload-hmd 最新のHMD週次CSVをserverへ送る（投入しない）'
	@echo 'make upload-wpp 最新のWPP年次CSVをserverへ送る（投入しない）'
	@echo 'make upload-oecd 最新のOECD乳児・周産期年次CSVをserverへ送る（投入しない）'
	@echo 'make upload-un-monthly 最新のUN月次死亡CSVをserverへ送る（投入しない）'
	@echo 'make upload-confirmed 日本確定数の人口・月次・週次・年次CSVをserverへ送る（投入しない）'
	@echo 'make logstash-official YEARLY_INDEX=mstats20260816 各国公式dataを指定indexへ投入'
	@echo 'make logstash-hmd YEARLY_INDEX=mstats20260816 HMDを指定indexへ投入'
	@echo 'make logstash-wpp YEARLY_INDEX=mstats20260816 WPPを指定indexへ投入'
	@echo 'make logstash-oecd YEARLY_INDEX=mstats20260816 OECD乳児・周産期dataを指定indexへ投入'
	@echo 'make logstash-un-monthly YEARLY_INDEX=mstats20260816 UN月次死亡dataを指定indexへ投入'
	@echo 'make logstash-confirmed YEARLY_INDEX=mstats20260816 日本確定数dataを指定indexへ投入'
	@echo 'make upload-exdeaths-sample 全国7系列の短縮CSVをserverへ送る（投入しない）'
	@echo 'make logstash-exdeaths-sample YEARLY_INDEX=mstats20260816 全国7系列を指定indexへ投入'
	@echo 'make upload-exdeaths 全国・47都道府県の7系列CSVをserverへ送る（投入しない）'
	@echo 'make logstash-exdeaths YEARLY_INDEX=mstats20260816 全国・47都道府県の7系列を指定indexへ投入'
	@echo 'make upload-mstats-all 全系列の最新CSVをserverへ送りsymlinkを更新'
	@echo 'make check-latest-id-collisions 各系列の最新版1本ずつについて横断ID重複を検査'
	@echo 'make reset-mstats-index YEARLY_INDEX=mstats20260816 指定物理indexだけを削除・新規作成'
	@echo 'make check-mstats-index YEARLY_INDEX=mstats20260816 mappingと件数を表示'
	@echo 'make switch-mstats-alias YEARLY_INDEX=mstats20260816 mstats aliasをatomicに切替え'
	@echo 'make validate-csv FILES="..." 投入前に期間・ID・値・出典を検査'
	@echo 'make cod      CSV更新があればサーバへ送りLogstashで投入'
	@echo 'make codtr    make codと同じデータ更新（codtr.rbは年未完の月も表示）'
	@echo 'make upload   最新の人口・月次死因・週次死因CSVをサーバへ送る'
	@echo 'make logstash サーバ上でmstats2026.confを一回実行'

fetch: fetch-pop fetch-death

location-config:
	@ruby "$(ROOT)/bin/export-areas.rb" "$(ROOT)/config/areas.json"
	@python3 "$(ROOT)/bin/export-regions.py" "$(WPP_DEMOGRAPHIC)" "$(ROOT)/config/regions.json"
	@cp "$(ROOT)/config/regions.json" "$(ROOT)/../web/mort-regions.json"
	@echo 'updated config/areas.json, config/regions.json, and web/mort-regions.json'

all: fetch cod

fetch-pop:
	@mkdir -p "$(STATE_DIR)"; \
	 result="$(STATE_DIR)/codex-pop-result.txt"; log="$(STATE_DIR)/codex-pop.log"; rm -f "$$result" "$$log"; \
	 files=("$(POP_ARCHIVE_DIR)"/*.csv(N)); names=(); for file in "$${files[@]}"; do names+=("$${file:t:r}"); done; names=("$${(@on)names}"); \
	 latest=$${names[-1]}; next=$$(date -j -f '%Y-%m' -v+1m "$$latest" '+%Y-%m'); SECONDS=0; \
	 prompt="$(POP_URL)を起点に、人口推計月次の$${next}以降が新しく公開されているかだけを確認してください。$(POP_ARCHIVE_DIR)にある既存CSVの内容は読まず、検証もしないでください。公開済みならe-Statが提供するCSVを$(POP_ARCHIVE_DIR)/YYYY-MM.csvとして保存し、既存ファイルは変更・上書きしないでください。XLSXの解析やCSVへの変換は不要です。連続して複数月が公開済みなら取得し、最初の未公開月で止めてください。リポジトリ内のコードは変更しないでください。最後に取得した月、または$${next}が未公開だったことだけを日本語で簡潔に報告してください。"; \
	 echo; \
	 echo "[Codex] 人口推計月次の$${next}以降が公開済みか確認します。"; \
	 echo '[Codex] 起点URL: $(POP_URL)'; \
	 echo '[Codex] 既存原CSVの内容確認・変換・検証は行いません。'; \
	 unsetopt BG_NICE; \
	 { print -r -- "$$prompt" | $(CODEX) --ask-for-approval never --search exec --ephemeral --sandbox workspace-write -c sandbox_workspace_write.network_access=true --add-dir "$(POP_ARCHIVE_DIR)" -C "$(ROOT)" -o "$$result" -; } > "$$log" 2>&1 & pid=$$!; \
	 trap 'kill $$pid 2>/dev/null || true; wait $$pid 2>/dev/null || true; exit 130' INT TERM; \
	 while kill -0 $$pid 2>/dev/null; do sleep 10; kill -0 $$pid 2>/dev/null || break; echo "[Codex] 人口$${next}以降の公開有無を確認中... $${SECONDS}秒"; done; \
	 if wait $$pid; then \
	   if [[ -f $$result ]]; then cat "$$result"; echo; fi; echo; \
	 else \
	   echo '[error] Codexによる人口CSV取得に失敗しました。'; cat "$$log"; exit 1; \
	 fi

fetch-death:
	@mkdir -p "$(STATE_DIR)"; \
	 result="$(STATE_DIR)/codex-death-result.txt"; log="$(STATE_DIR)/codex-death.log"; rm -f "$$result" "$$log"; \
	 files=("$(DCAUSE_SOURCE_DIR)"/*.csv(N)); names=(); for file in "$${files[@]}"; do names+=("$${file:t:r}"); done; names=("$${(@on)names}"); \
	 latest=$${names[-1]}; next=$$(date -j -f '%Y-%m' -v+1m "$$latest" '+%Y-%m'); SECONDS=0; \
	 prompt="$(DCAUSE_URL)を起点に、人口動態統計月報概数の$${next}以降に対応する保管第6表・死因簡単分類CSVが新しく公開されているかだけを確認してください。$(DCAUSE_SOURCE_DIR)にある既存CSVの内容は読まず、検証もしないでください。公開済みならe-Statが提供するCSVを$(DCAUSE_SOURCE_DIR)/YYYY-MM.csvとして保存し、既存ファイルは変更・上書きしないでください。XLSXの解析やCSVへの変換は不要です。連続して複数月が公開済みなら取得し、最初の未公開月で止めてください。リポジトリ内のコードは変更しないでください。最後に取得した月、または$${next}が未公開だったことだけを日本語で簡潔に報告してください。"; \
	 echo; \
	 echo "[Codex] 月次死因CSVの$${next}以降が公開済みか確認します。"; \
	 echo '[Codex] 起点URL: $(DCAUSE_URL)'; \
	 echo '[Codex] 既存原CSVの内容確認・変換・検証は行いません。'; \
	 unsetopt BG_NICE; \
	 { print -r -- "$$prompt" | $(CODEX) --ask-for-approval never --search exec --ephemeral --sandbox workspace-write -c sandbox_workspace_write.network_access=true --add-dir "$(DCAUSE_SOURCE_DIR)" -C "$(ROOT)" -o "$$result" -; } > "$$log" 2>&1 & pid=$$!; \
	 trap 'kill $$pid 2>/dev/null || true; wait $$pid 2>/dev/null || true; exit 130' INT TERM; \
	 while kill -0 $$pid 2>/dev/null; do sleep 10; kill -0 $$pid 2>/dev/null || break; echo "[Codex] 死因$${next}以降の公開有無を確認中... $${SECONDS}秒"; done; \
	 if wait $$pid; then \
	   if [[ -f $$result ]]; then cat "$$result"; echo; fi; echo; \
	 else \
	   echo '[error] Codexによる死因CSV取得に失敗しました。'; cat "$$log"; exit 1; \
	 fi

fetch-stmf:
	@mkdir -p "$(STMF_DIR)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 out="$(STMF_DIR)/stmf-$$stamp.csv"; \
	 echo '[fetch-stmf] HMDからSTMF pooled CSVを取得します。'; \
	 if ! ruby "$(ROOT)/import/fetch-stmf.rb" "$$out"; then rm -f "$$out"; exit 1; fi; \
	 ln -sfn "$${out:t}" "$(STMF_SOURCE)"; \
	echo "updated $(STMF_SOURCE) -> $${out:t}"

fetch-exdeaths:
	@mkdir -p "$(EXDEATHS_DIR)" "$(EXDEATHS_CAUSE_DIR)"; \
	 all_tmp="$(EXDEATHS_ALL).tmp"; cause_tmp="$(EXDEATHS_CAUSE_ARCHIVE).tmp"; \
	 curl -fL --retry 3 '$(EXDEATHS_URL)' -o "$$all_tmp"; \
	 curl -fL --retry 3 '$(EXDEATHS_CAUSE_URL)' -o "$$cause_tmp"; \
	 [[ $$(head -1 "$$all_tmp" | tr -d '\r') == 'prefecture_id,prefectureJP,prefecture_EN,week_ending_date,Observed_weighted,Observed' ]] || { rm -f "$$all_tmp" "$$cause_tmp"; echo 'unexpected Observed.csv header'; exit 1; }; \
	 unzip -t "$$cause_tmp" >/dev/null; old_causes=("$(EXDEATHS_CAUSE_DIR)"/*.csv(N)); (( $$#old_causes == 0 )) || rm -f $$old_causes; \
	 unzip -q "$$cause_tmp" -d "$(EXDEATHS_CAUSE_DIR)"; \
	 mv "$$all_tmp" "$(EXDEATHS_ALL)"; mv "$$cause_tmp" "$(EXDEATHS_CAUSE_ARCHIVE)"; \
	 echo 'updated exdeaths-japan.org source CSVs'

exdeaths-sample-csv:
	@test -s "$(EXDEATHS_ALL)" || { echo '先に make fetch-exdeaths を実行してください。'; exit 1; }
	@mkdir -p "$(DATA_DIR)" "$(STATE_DIR)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 out="$(DATA_DIR)/exdeaths-weekly-national-mstats2026-$$stamp.csv"; tmp="$$out.tmp"; log="$(STATE_DIR)/exdeaths-sample.log"; \
	 started=$$SECONDS; \
	 if ! ruby "$(ROOT)/import/exdeaths-weekly.rb" --prefecture-ids 48 --through 2024-12-29 \
	   "$(EXDEATHS_ALL)" "$(EXDEATHS_CAUSE_DIR)" > "$$tmp" 2> "$$log"; then cat "$$log"; rm -f "$$tmp"; exit 1; fi; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$tmp"; \
	 mv "$$tmp" "$$out"; echo "created $$out"; echo "[timing] national conversion/validation: $$((SECONDS - started))s"

exdeaths-csv:
	@test -s "$(EXDEATHS_ALL)" || { echo '先に make fetch-exdeaths を実行してください。'; exit 1; }
	@mkdir -p "$(DATA_DIR)" "$(STATE_DIR)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 out="$(DATA_DIR)/exdeaths-weekly-mstats2026-$$stamp.csv"; tmp="$$out.tmp"; log="$(STATE_DIR)/exdeaths.log"; \
	 started=$$SECONDS; \
	 if ! ruby "$(ROOT)/import/exdeaths-weekly.rb" "$(EXDEATHS_ALL)" "$(EXDEATHS_CAUSE_DIR)" > "$$tmp" 2> "$$log"; then cat "$$log"; rm -f "$$tmp"; exit 1; fi; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$tmp"; \
	 mv "$$tmp" "$$out"; cat "$$log"; echo "created $$out"; echo "[timing] all-area conversion/validation: $$((SECONDS - started))s"

fetch-wpp:
	@mkdir -p "$(WPP_DIR)"; \
	 for name in \
	   WPP2024_Demographic_Indicators_Medium.csv.gz \
	   WPP2024_DeathsBySingleAgeSex_Medium_1950-2023.csv.gz \
	   WPP2024_DeathsBySingleAgeSex_Medium_2024-2100.csv.gz \
	   WPP2024_PopulationExposureBySingleAgeSex_Medium_1950-2023.csv.gz \
	   WPP2024_PopulationExposureBySingleAgeSex_Medium_2024-2100.csv.gz; do \
	   dst="$(WPP_DIR)/$$name"; tmp="$$dst.tmp"; \
	   echo "[fetch-wpp] $$name"; \
	   curl -L --fail --retry 8 --retry-all-errors --silent --show-error \
	     "$(WPP_BASE_URL)/$$name" -o "$$tmp"; \
	   gzip -t "$$tmp"; mv "$$tmp" "$$dst"; \
	 done

check:
	@pop_sources=("$(POP_ARCHIVE_DIR)"/*.csv(N)); \
	 death_sources=("$(DCAUSE_SOURCE_DIR)"/*.csv(N)); \
	 (( $$#pop_sources )) || { echo '人口原CSVがありません: $(POP_ARCHIVE_DIR)'; exit 1; }; \
	 (( $$#death_sources )) || { echo '死因原CSVがありません: $(DCAUSE_SOURCE_DIR)'; exit 1; }; \
	 echo '[check] 原CSVの月抜け・重複・空ファイルを確認します。'; \
	 $(VALIDATE_MONTHS); $(VALIDATE_CSV); \
	 validate_months pop "$${pop_sources[@]}" || exit 1; validate_months death "$${death_sources[@]}" || exit 1; \
	 tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	 echo '[check] 人口原CSVを一時変換し、mstats2026形式を確認します。'; \
	 if ! ruby "$(ROOT)/import/jp-pop.rb" "$${pop_sources[@]}" > "$$tmp/pop.csv" 2> "$$tmp/pop.log"; then cat "$$tmp/pop.log"; exit 1; fi; \
	 validate_csv pop "$$tmp/pop.csv"; \
	 echo '[check] 死因原CSVを一時変換し、mstats2026形式を確認します。'; \
	 if ! ruby "$(ROOT)/import/jp-dcause.rb" "$${death_sources[@]}" > "$$tmp/death.csv" 2> "$$tmp/death.log"; then cat "$$tmp/death.log"; exit 1; fi; \
	 validate_csv death "$$tmp/death.csv"; \
	 echo '[check] OK: 月抜け・重複・空ファイル・CSV形式・ID重複・必須人口値に問題はありません。'

csv:
	@pop_sources=("$(POP_ARCHIVE_DIR)"/*.csv(N)); \
	 death_sources=("$(DCAUSE_SOURCE_DIR)"/*.csv(N)); \
	 (( $$#pop_sources && $$#death_sources )) || { echo '原CSVが不足しています。先に make check を実行してください。'; exit 1; }; \
	 mkdir -p "$(DATA_DIR)" "$(STATE_DIR)"; rm -f "$(STATE_DIR)/csv-updated"; \
	 echo '[csv] 原CSVの変更を確認します。'; \
	 $(VALIDATE_MONTHS); $(VALIDATE_CSV); $(VALIDATE_WEEKLY_CSV); \
	 validate_months pop "$${pop_sources[@]}" || exit 1; validate_months death "$${death_sources[@]}" || exit 1; \
	 for file in "$${pop_sources[@]}"; do shasum -a 256 "$$file"; done | LC_ALL=C sort > "$(STATE_DIR)/pop.current"; \
	 for file in "$${death_sources[@]}"; do shasum -a 256 "$$file"; done | LC_ALL=C sort > "$(STATE_DIR)/death.current"; \
	 changed=0; pop_changed=0; death_changed=0; stamp=$$(date +%Y%m%d-%H%M%S); \
	 cmp -s "$(STATE_DIR)/pop.current" "$(STATE_DIR)/pop.sources" || pop_changed=1; \
	 cmp -s "$(STATE_DIR)/death.current" "$(STATE_DIR)/death.sources" || death_changed=1; \
	 if (( pop_changed )); then \
	    echo '[csv] 人口の日時付き累積CSVを生成します。'; \
	    tmp="$(DATA_DIR)/.jp-pop-mstats2026-$$stamp.csv.tmp"; out="$(DATA_DIR)/jp-pop-mstats2026-$$stamp.csv"; \
	    if ! ruby "$(ROOT)/import/jp-pop.rb" "$${pop_sources[@]}" > "$$tmp" 2> "$(STATE_DIR)/jp-pop.log"; then cat "$(STATE_DIR)/jp-pop.log"; exit 1; fi; \
	    validate_csv pop "$$tmp"; mv "$$tmp" "$$out"; \
	    echo "created $$out"; \
	  fi; \
	 if (( pop_changed || death_changed )); then \
	    pop_files=("$(DATA_DIR)"/jp-pop-mstats2026-*.csv(Nom)); pop=$$pop_files[1]; \
	    test -n "$$pop" || { echo '人口CSVを生成できませんでした。'; exit 1; }; \
	    old_pop_files=("$(DATA_DIR)"/jp-pop-cfm-legacy-mstats2026-*.csv(Nom)); old_pop=$$old_pop_files[1]; weekly_pop="$$pop"; \
	    if [[ -n $$old_pop ]]; then weekly_pop="$(STATE_DIR)/jp-pop-history.csv"; \
	      { head -1 "$$old_pop"; tail -n +2 "$$old_pop"; tail -n +2 "$$pop"; } > "$$weekly_pop"; fi; \
	    cfm_monthly_files=("$(DATA_DIR)"/jp-dcause-cfm-mstats2026-*.csv(Nom)); cfm_monthly=$$cfm_monthly_files[1]; \
	    weekly_priority=(); [[ -z $$cfm_monthly ]] || weekly_priority=(--preferred-monthly "$$cfm_monthly"); \
	    monthly="$(DATA_DIR)/jp-dcause-mstats2026-$$stamp.csv"; \
	    weekly="$(DATA_DIR)/jp-dcause-weekly-mstats2026-$$stamp.csv"; \
	    echo '[csv] 原死因CSVを一度読み、月次・週次CSVを同時生成します。'; \
	    if ! ruby "$(ROOT)/import/causejp.rb" --population "$$weekly_pop" --monthly-out "$$monthly" --weekly-out "$$weekly" \
	      "$${weekly_priority[@]}" "$${death_sources[@]}" 2> "$(STATE_DIR)/causejp.log"; then cat "$(STATE_DIR)/causejp.log"; rm -f "$$monthly" "$$weekly"; exit 1; fi; \
	    validate_csv death "$$monthly" || { rm -f "$$monthly" "$$weekly"; exit 1; }; \
	    validate_weekly_csv "$$weekly" || { rm -f "$$monthly" "$$weekly"; exit 1; }; \
	    cat "$(STATE_DIR)/causejp.log"; echo "created $$monthly"; echo "created $$weekly"; \
	    (( pop_changed )) && cp "$(STATE_DIR)/pop.current" "$(STATE_DIR)/pop.sources"; \
	    (( death_changed )) && cp "$(STATE_DIR)/death.current" "$(STATE_DIR)/death.sources"; \
	    changed=1; \
	  fi; \
	 if (( changed )); then touch "$(STATE_DIR)/csv-updated"; else \
	    pop_names=(); for file in "$${pop_sources[@]}"; do pop_names+=("$${file:t:r}"); done; pop_names=("$${(@on)pop_names}"); \
	    death_names=(); for file in "$${death_sources[@]}"; do death_names+=("$${file:t:r}"); done; death_names=("$${(@on)death_names}"); \
	    pop_latest=$${pop_names[-1]}; death_latest=$${death_names[-1]}; \
	    pop_next=$$(date -j -f '%Y-%m' -v+1m "$$pop_latest" '+%Y-%m'); \
	    death_next=$$(date -j -f '%Y-%m' -v+1m "$$death_latest" '+%Y-%m'); \
	    echo "新しい人口推計月次（$${pop_next}以降）を取ってきて、とAIに頼んでください。場所は" '$(POP_URL)'; \
	    echo "新しい月次死因CSV（$${death_next}以降）を取ってきて、とAIに頼んでください。場所は" '$(DCAUSE_URL)'; \
	  fi

schema-csv:
	@pop_sources=("$(POP_ARCHIVE_DIR)"/*.csv(N)); death_sources=("$(DCAUSE_SOURCE_DIR)"/*.csv(N)); \
	 (( $$#pop_sources && $$#death_sources )) || { echo '原CSVが不足しています。'; exit 1; }; \
	 mkdir -p "$(DATA_DIR)" "$(STATE_DIR)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 pop="$(DATA_DIR)/jp-pop-mstats2026-$$stamp.csv"; \
	 monthly="$(DATA_DIR)/jp-dcause-mstats2026-$$stamp.csv"; \
	 weekly="$(DATA_DIR)/jp-dcause-weekly-mstats2026-$$stamp.csv"; \
	 cfm_monthly_files=("$(DATA_DIR)"/jp-dcause-cfm-mstats2026-*.csv(Nom)); cfm_monthly=$$cfm_monthly_files[1]; \
	 weekly_priority=(); [[ -z $$cfm_monthly ]] || weekly_priority=(--preferred-monthly "$$cfm_monthly"); \
	 echo '[schema-csv] 人口CSVを新しいdata形式で再生成します。'; \
	 ruby "$(ROOT)/import/jp-pop.rb" "$${pop_sources[@]}" > "$$pop"; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$pop"; \
	 old_pop_files=("$(DATA_DIR)"/jp-pop-cfm-legacy-mstats2026-*.csv(Nom)); old_pop=$$old_pop_files[1]; weekly_pop="$$pop"; \
	 if [[ -n $$old_pop ]]; then weekly_pop="$(STATE_DIR)/jp-pop-history.csv"; \
	   { head -1 "$$old_pop"; tail -n +2 "$$old_pop"; tail -n +2 "$$pop"; } > "$$weekly_pop"; fi; \
	 echo '[schema-csv] 月次死亡・週次派生CSVを新しいdata形式で再生成します。'; \
	 ruby "$(ROOT)/import/causejp.rb" --population "$$weekly_pop" --monthly-out "$$monthly" \
	   --weekly-out "$$weekly" "$${weekly_priority[@]}" "$${death_sources[@]}"; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$monthly" "$$weekly"; \
	echo "created $$pop"; echo "created $$monthly"; echo "created $$weekly"

confirmed-sample-csv:
	@annual="$(DCAUSE_CFM_YEARLY_DIR)/1999.csv"; book="$(POP_CFM_LEGACY_DIR)/1999.xls"; \
	 test -s "$$annual" -a -s "$$book" || { echo '1999年の短縮検査sourceが不足しています。'; exit 1; }; \
	 command -v soffice >/dev/null || { echo 'LibreOfficeのsofficeが必要です。'; exit 1; }; \
	 mkdir -p "$(STATE_DIR)"; tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	 cp "$$book" "$$tmp/1999.xls"; mkdir "$$tmp/csv"; \
	 echo '[confirmed-sample-csv] 1999年人口bookを変換します。'; \
	 launchctl asuser $$(id -u) soffice --headless \
	   --convert-to 'csv:Text - txt - csv (StarCalc):44,34,76,1,,0,false,true,true,false,false,-1' \
	   --outdir "$$tmp/csv" "$$tmp/1999.xls" >/dev/null; \
	 csv_files=("$$tmp/csv/"*.csv(N)); (( $$#csv_files == 3 )) || { echo "soffice created $$#csv_files of 3 expected population CSVs"; exit 1; }; \
	 ruby "$(ROOT)/import/jp-pop-confirmed-legacy.rb" --sample --oldest-output "$$tmp/oldest.csv" "$${csv_files[@]}" > "$$tmp/pop.csv"; \
	 ruby "$(ROOT)/import/jp-dcause-confirmed-yearly.rb" "$$annual" > "$$tmp/death.csv"; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$tmp/pop.csv" "$$tmp/death.csv"; \
	 ruby -rcsv -e 'ARGV.first(2).each { |path| rows = CSV.read(path, headers: true); abort "old over field: #$${path}" if rows.headers.any? { |h| h&.end_with?("over") }; abort "age_75plus leaked into shared schema" if rows.headers.include?("age_75plus"); abort "age_100plus missing: #$${path}" if File.basename(path) == "death.csv" && rows.none? { |r| !r["age_100plus"].to_s.empty? } }; oldest = CSV.read(ARGV[2], headers: true); abort "ASR sidecar missing age_75plus" unless oldest.headers == %w[yearmonth sex age_75plus] && oldest.any?; puts "confirmed sample validation=ok"' "$$tmp/pop.csv" "$$tmp/death.csv" "$$tmp/oldest.csv"

confirmed-csv:
	@cause_sources=("$(DCAUSE_CFM_DIR)"/<->.csv(N)); annual_sources=("$(DCAUSE_CFM_YEARLY_DIR)"/<->.csv(N)); pop_books=("$(POP_CFM_LEGACY_DIR)"/<->.xls(N)); \
	 overall=$$SECONDS; \
	 (( $$#cause_sources == 26 )) || { echo '確定死亡原CSVは1999〜2024年の26fileが必要です。'; exit 1; }; \
	 (( $$#annual_sources == 10 )) || { echo '年次確定死亡原CSVは1999〜2008年の10fileが必要です。'; exit 1; }; \
	 (( $$#pop_books == 11 )) || { echo '確定人口原bookは1999〜2009年の11fileが必要です。'; exit 1; }; \
	 regular_pop_files=("$(DATA_DIR)"/jp-pop-mstats2026-*.csv(Nom)); regular_pop=$$regular_pop_files[1]; \
	 test -n "$$regular_pop" || { echo '人口推計・月次公表表のCSVがありません。先に make schema-csv を実行してください。'; exit 1; }; \
	 command -v soffice >/dev/null || { echo 'LibreOfficeのsofficeが必要です。'; exit 1; }; \
	 mkdir -p "$(DATA_DIR)" "$(STATE_DIR)"; tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; mkdir "$$tmp/books" "$$tmp/pop-csv"; \
	 cp "$${pop_books[@]}" "$$tmp/books/"; \
	 echo '[confirmed-csv] 確定人口bookの全sheetをCSVへ変換します。'; \
	 started=$$SECONDS; \
	 launchctl asuser $$(id -u) soffice --headless \
	   --convert-to 'csv:Text - txt - csv (StarCalc):44,34,76,1,,0,false,true,true,false,false,-1' \
	   --outdir "$$tmp/pop-csv" "$$tmp/books/"*.xls >/dev/null; \
	 converted_books=("$$tmp/pop-csv/"*.csv(N)); \
	 (( $$#converted_books >= $$#pop_books )) || { echo "soffice created only $$#converted_books CSVs from $$#pop_books population books"; exit 1; }; \
	 echo "[timing] population book conversion: $$((SECONDS - started))s"; \
	 stamp=$$(date +%Y%m%d-%H%M%S); pop_old="$(DATA_DIR)/jp-pop-cfm-legacy-mstats2026-$$stamp.csv"; annual_raw="$(DATA_DIR)/jp-dcause-cfm-yearly-raw-mstats2026-$$stamp.csv"; \
	 monthly="$(DATA_DIR)/jp-dcause-cfm-mstats2026-$$stamp.csv"; weekly="$(DATA_DIR)/jp-dcause-weekly-mstats2026-$$stamp.csv"; \
	 yearly="$(DATA_DIR)/jp-yearly-cfm-mstats2026-$$stamp.csv"; combined="$$tmp/jp-pop-combined.csv"; oldest="$$tmp/jp-pop-oldest.csv"; \
	 pop_all="$$tmp/jp-pop-cfm-legacy-all.csv"; \
	 started=$$SECONDS; ruby "$(ROOT)/import/jp-pop-confirmed-legacy.rb" --oldest-output "$$oldest" \
	   --all-output "$$pop_all" --exclude-ids "$$regular_pop" "$${converted_books[@]}" > "$$pop_old" || exit 1; \
	 echo "[timing] population CSV generation: $$((SECONDS - started))s"; \
	 started=$$SECONDS; ruby "$(ROOT)/import/jp-dcause-confirmed.rb" "$${cause_sources[@]}" > "$$monthly" || exit 1; \
	 echo "[timing] monthly death generation: $$((SECONDS - started))s"; \
	 started=$$SECONDS; ruby "$(ROOT)/import/jp-dcause-confirmed-yearly.rb" "$${annual_sources[@]}" > "$$annual_raw" || exit 1; \
	 echo "[timing] annual death generation: $$((SECONDS - started))s"; \
	 { head -1 "$$pop_all"; tail -n +2 "$$pop_all"; tail -n +2 "$$regular_pop"; } > "$$combined"; \
	 regular_death_files=("$(DATA_DIR)"/jp-dcause-mstats2026-*.csv(Nom)); regular_death=$$regular_death_files[1]; \
	 test -n "$$regular_death" || { echo '概数・速報月次死亡CSVがありません。先に make schema-csv を実行してください。'; exit 1; }; \
	 started=$$SECONDS; ruby "$(ROOT)/import/jp-dcause-weekly.rb" --population "$$combined" \
	   --preferred-monthly "$$monthly" "$$regular_death" > "$$weekly" || exit 1; \
	 echo "[timing] weekly death generation: $$((SECONDS - started))s"; \
	 started=$$SECONDS; ruby "$(ROOT)/import/jp-yearly.rb" --annual-death "$$annual_raw" --oldest-pop "$$oldest" \
	   --deaths-only "$$monthly" "$$combined" > "$$yearly" || exit 1; \
	 echo "[timing] annual population/rate generation: $$((SECONDS - started))s"; \
	 started=$$SECONDS; ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$annual_raw" || exit 1; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$pop_old" "$$monthly" "$$weekly" "$$yearly" || exit 1; \
	 echo "[timing] CSV validation: $$((SECONDS - started))s"; \
	 echo "created $$pop_old ($$(($$(wc -l < "$$pop_old") - 1)) records)"; \
	 echo "created $$monthly ($$(($$(wc -l < "$$monthly") - 1)) records)"; \
	 echo "created $$weekly ($$(($$(wc -l < "$$weekly") - 1)) records; confirmed then provisional)"; \
	 echo "created $$annual_raw ($$(($$(wc -l < "$$annual_raw") - 1)) records)"; \
	 echo "created $$yearly ($$(($$(wc -l < "$$yearly") - 1)) records)"; \
	 echo "[timing] confirmed-csv total: $$((SECONDS - overall))s"; \
	 echo '[confirmed-csv] uploadとElasticsearch投入は行っていません。'

canonical-weekly-csv:
	@old_pop_files=("$(DATA_DIR)"/jp-pop-cfm-legacy-mstats2026-*.csv(Nom)); old_pop=$$old_pop_files[1]; \
	 pop_files=("$(DATA_DIR)"/jp-pop-mstats2026-*.csv(Nom)); pop=$$pop_files[1]; \
	 cfm_files=("$(DATA_DIR)"/jp-dcause-cfm-mstats2026-*.csv(Nom)); cfm=$$cfm_files[1]; \
	 current_files=("$(DATA_DIR)"/jp-dcause-mstats2026-*.csv(Nom)); current=$$current_files[1]; \
	 test -n "$$old_pop" -a -n "$$pop" -a -n "$$cfm" -a -n "$$current" || { echo 'canonical週次生成用CSVが不足しています。'; exit 1; }; \
	 work=$$(mktemp -d); trap 'rm -rf "$$work"' EXIT; \
	 { head -1 "$$old_pop"; tail -n +2 "$$old_pop"; tail -n +2 "$$pop"; } > "$$work/pop.csv"; \
	 stamp=$$(date +%Y%m%d-%H%M%S); out="$(DATA_DIR)/jp-dcause-weekly-mstats2026-$$stamp.csv"; \
	 started=$$SECONDS; ruby "$(ROOT)/import/jp-dcause-weekly.rb" --population "$$work/pop.csv" \
	   --preferred-monthly "$$cfm" "$$current" > "$$out"; \
	 echo "[timing] canonical weekly generation: $$((SECONDS - started))s"; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$out"; \
	 echo "created $$out ($$(($$(wc -l < "$$out") - 1)) records)"

mort-csv:
	@pop_files=("$(DATA_DIR)"/jp-pop-mstats2026-*.csv(Nom)); pop=$$pop_files[1]; \
	 death_files=("$(DATA_DIR)"/jp-dcause-mstats2026-*.csv(Nom)); death=$$death_files[1]; \
	 test -n "$$pop" -a -n "$$death" || { echo 'mstats2026月次CSVが不足しています。先に make csv を実行してください。'; exit 1; }; \
	 mkdir -p "$(DATA_DIR)" "$(STATE_DIR)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 tmp="$(DATA_DIR)/.jp-dcause-weekly-mstats2026-$$stamp.csv.tmp"; \
	 out="$(DATA_DIR)/jp-dcause-weekly-mstats2026-$$stamp.csv"; \
	 log="$(STATE_DIR)/jp-dcause-weekly.log"; \
	 echo "[mort-csv] $${death:t}と$${pop:t}から週次CSVを生成します。"; \
	 if ! ruby "$(ROOT)/import/jp-dcause-weekly.rb" --population "$$pop" "$$death" > "$$tmp" 2> "$$log"; then cat "$$log"; rm -f "$$tmp"; exit 1; fi; \
	 header=$$(head -1 "$$tmp"); \
	 [[ $$header == id,loc,area,areaj,yearweek,category,*age_50_64 ]] || { echo "wrong weekly mstats2026 header: $$tmp"; rm -f "$$tmp"; exit 1; }; \
	 rows=$$(( $$(wc -l < "$$tmp") - 1 )); (( rows > 0 )) || { echo "no weekly data rows: $$tmp"; rm -f "$$tmp"; exit 1; }; \
	 duplicates=$$(tail -n +2 "$$tmp" | cut -d, -f1 | LC_ALL=C sort | uniq -d | head -1); \
	 [[ -z $$duplicates ]] || { echo "duplicate weekly id: $$duplicates"; rm -f "$$tmp"; exit 1; }; \
	 periods=$$(tail -n +2 "$$tmp" | cut -d, -f5 | LC_ALL=C sort -u); \
	 first=$$(print -r -- "$$periods" | head -1); last=$$(print -r -- "$$periods" | tail -1); \
	 mv "$$tmp" "$$out"; \
	 echo "created $$out: rows=$$rows periods=$$(print -r -- "$$periods" | wc -l | tr -d ' ') ($$first..$$last)"; \
	 echo '[mort-csv] uploadとElasticsearch投入はまだ行いません。'

stmf-csv:
	@source="$(STMF_SOURCE)"; test -s "$$source" || { echo 'STMF pooled CSVがありません: $(STMF_SOURCE)'; exit 1; }; \
	 mkdir -p "$(DATA_DIR)" "$(STATE_DIR)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 tmp="$(DATA_DIR)/.stmf-weekly-mstats2026-$$stamp.csv.tmp"; \
	 out="$(DATA_DIR)/stmf-weekly-mstats2026-$$stamp.csv"; \
	 log="$(STATE_DIR)/stmf-weekly.log"; \
	 echo "[stmf-csv] $${source:t}を週次CSVへ変換します。"; \
	 if ! ruby "$(ROOT)/import/stmf-weekly.rb" "$$source" > "$$tmp" 2> "$$log"; then cat "$$log"; rm -f "$$tmp"; exit 1; fi; \
	 rows=$$(( $$(wc -l < "$$tmp") - 1 )); (( rows > 0 )) || { echo "no STMF rows: $$tmp"; rm -f "$$tmp"; exit 1; }; \
	 duplicates=$$(tail -n +2 "$$tmp" | cut -d, -f1 | LC_ALL=C sort | uniq -d | head -1); \
	 [[ -z $$duplicates ]] || { echo "duplicate STMF id: $$duplicates"; rm -f "$$tmp"; exit 1; }; \
	 periods=$$(tail -n +2 "$$tmp" | cut -d, -f5 | LC_ALL=C sort -u); \
	 first=$$(print -r -- "$$periods" | head -1); last=$$(print -r -- "$$periods" | tail -1); \
	 mv "$$tmp" "$$out"; \
	 echo "created $$out: rows=$$rows periods=$$(print -r -- "$$periods" | wc -l | tr -d ' ') ($$first..$$last)"; \
	 echo '[stmf-csv] uploadとElasticsearch投入はまだ行いません。'

yearly-csv: jp-yearly-csv

jp-yearly-csv:
	@pop_files=("$(DATA_DIR)"/jp-pop-mstats2026-*.csv(Nom)); pop=$$pop_files[1]; \
	 old_pop_files=("$(DATA_DIR)"/jp-pop-cfm-legacy-mstats2026-*.csv(Nom)); old_pop=$$old_pop_files[1]; \
	 death_files=("$(DATA_DIR)"/jp-dcause-mstats2026-*.csv(Nom)); death=$$death_files[1]; \
	 test -n "$$pop" -a -n "$$old_pop" -a -n "$$death" || { echo '月次CSVが不足しています。先に make schema-csv confirmed-csv を実行してください。'; exit 1; }; \
	 mkdir -p "$(DATA_DIR)"; work=$$(mktemp -d); trap 'rm -rf "$$work"' EXIT; \
	 { head -1 "$$old_pop"; tail -n +2 "$$old_pop"; tail -n +2 "$$pop"; } > "$$work/pop-history.csv"; \
	 stamp=$$(date +%Y%m%d-%H%M%S); \
	 out="$(DATA_DIR)/jp-yearly-mstats2026-$$stamp.csv"; tmp="$$out.tmp"; \
	 ruby "$(ROOT)/import/jp-yearly.rb" "$$death" "$$work/pop-history.csv" > "$$tmp"; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$tmp"; \
	 mv "$$tmp" "$$out"; echo "created $$out"

us-yearly-csv:
	@test -s "$(US_MORTYEAR_SOURCE)"
	@mkdir -p "$(DATA_DIR)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 out="$(DATA_DIR)/us-yearly-mstats2026-$$stamp.csv"; tmp="$$out.tmp"; \
	 if ! ruby "$(ROOT)/import/us-infant-yearly.rb" "$(US_MORTYEAR_SOURCE)" > "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 if ! ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 mv "$$tmp" "$$out"; echo "created $$out"

oecd-infant-yearly-csv:
	@mkdir -p "$(OECD_DIR)" "$(DATA_DIR)"; tmp_source="$(OECD_MIM_SOURCE).tmp"; \
	 if ! curl -fsSL -H 'Accept: text/csv' '$(OECD_MIM_URL)' -o "$$tmp_source"; then rm -f "$$tmp_source"; exit 1; fi; \
	 header=$$(head -1 "$$tmp_source" | tr -d '\r'); \
	 if test "$$header" != 'DATAFLOW,REF_AREA,FREQ,MEASURE,UNIT_MEASURE,AGE,SEX,SOCIO_ECON_STATUS,DEATH_CAUSE,CALC_METHODOLOGY,GESTATION_THRESHOLD,HEALTH_STATUS,DISEASE,CANCER_SITE,TIME_PERIOD,OBS_VALUE,DECIMALS,OBS_STATUS,OBS_STATUS2,OBS_STATUS3,UNIT_MULT'; then rm -f "$$tmp_source"; echo 'unexpected OECD CSV header'; exit 1; fi; \
	 mv "$$tmp_source" "$(OECD_MIM_SOURCE)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 out="$(DATA_DIR)/oecd-infant-yearly-mstats2026-$$stamp.csv"; tmp="$$out.tmp"; \
	 if ! ruby "$(ROOT)/import/oecd-infant-yearly.rb" "$(OECD_MIM_SOURCE)" "$(WPP_DEMOGRAPHIC)" > "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 if ! ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 mv "$$tmp" "$$out"; echo "created $$out"; \
	 echo '[oecd-infant-yearly-csv] uploadとElasticsearch投入は行いません。'

jp-infant-yearly-csv:
	@test -s "$(JP_INFANT_SOURCE)" || { echo "日本乳児死亡sourceがありません: $(JP_INFANT_SOURCE)"; exit 1; }
	@test -s "$(JP_PERINATAL_SOURCE)" || { echo "日本周産期死亡sourceがありません: $(JP_PERINATAL_SOURCE)"; exit 1; }
	@mkdir -p "$(DATA_DIR)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 out="$(DATA_DIR)/jp-infant-yearly-mstats2026-$$stamp.csv"; tmp="$$out.tmp"; \
	 if ! ruby "$(ROOT)/import/jp-infant-yearly.rb" "$(JP_INFANT_SOURCE)" "$(JP_PERINATAL_SOURCE)" > "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 if ! ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 mv "$$tmp" "$$out"; echo "created $$out"; \
	 echo '[jp-infant-yearly-csv] uploadとElasticsearch投入は行いません。'

wpp-yearly-csv:
	@for file in "$(WPP_DEMOGRAPHIC)" "$(WPP_DEATH_HIST)" "$(WPP_DEATH_PROJ)" \
	  "$(WPP_EXPOSURE_HIST)" "$(WPP_EXPOSURE_PROJ)"; do \
	   test -s "$$file" || { echo "WPP source is missing: $$file"; exit 1; }; \
	   gzip -t "$$file"; \
	 done; \
	 mkdir -p "$(DATA_DIR)"; stamp=$$(date +%Y%m%d-%H%M%S); \
	 out="$(DATA_DIR)/un-wpp-yearly-mstats2026-$$stamp.csv"; tmp="$$out.tmp"; \
	 if ! python3 "$(ROOT)/import/un-wpp-yearly.py" \
	   "$(WPP_DEMOGRAPHIC)" "$(WPP_DEATH_HIST)" "$(WPP_DEATH_PROJ)" \
	   "$(WPP_EXPOSURE_HIST)" "$(WPP_EXPOSURE_PROJ)" > "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 if ! ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 mv "$$tmp" "$$out"; echo "created $$out"; \
	 echo '[wpp-yearly-csv] uploadとElasticsearch投入は行いません。'

fetch-un-monthly:
	@mkdir -p "$(UN_MONTHLY_DIR)"; tmp="$(UN_MONTHLY_ARCHIVE).tmp"; unpack=$$(mktemp -d); \
	 trap 'rm -f "$$tmp"; rm -rf "$$unpack"' EXIT; \
	 curl -fL --retry 3 --retry-delay 5 '$(UN_MONTHLY_URL)' -o "$$tmp"; \
	 test -s "$$tmp" || { echo 'UNdata download is empty'; exit 1; }; \
	 unzip -t "$$tmp"; unzip -q "$$tmp" -d "$$unpack"; \
	 files=("$$unpack"/*.csv(N)); (( $${#files} == 1 )) || { echo 'UNdata archive must contain exactly one CSV'; exit 1; }; \
	 header=$$(head -1 "$$files[1]" | tr -d '\r'); \
	 [[ $$header == '"Country or Area","Year","Area","Month","Record Type","Reliability","Source Year","Value","Value Footnotes"'* ]] || { echo "unexpected UNdata header: $$header"; exit 1; }; \
	 mv "$$tmp" "$(UN_MONTHLY_ARCHIVE)"; cp "$$files[1]" "$(UN_MONTHLY_SOURCE)"; \
	 echo "created $(UN_MONTHLY_SOURCE)"

un-monthly-csv:
	@test -s "$(UN_MONTHLY_SOURCE)" || { echo "UN monthly source is missing: $(UN_MONTHLY_SOURCE)"; exit 1; }
	@wpp_files=("$(DATA_DIR)"/un-wpp-yearly-mstats2026-*.csv(Nom)); wpp=$$wpp_files[1]; \
	 test -n "$$wpp" || { echo 'WPP年次CSVがありません。'; exit 1; }; \
	 stamp=$$(date +%Y%m%d-%H%M%S); out="$(DATA_DIR)/un-monthly-mortality-mstats2026-$$stamp.csv"; tmp="$$out.tmp"; \
	 if ! ruby "$(ROOT)/import/un-monthly-mortality.rb" "$(UN_MONTHLY_SOURCE)" "$$wpp" > "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 if ! ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$tmp"; then rm -f "$$tmp"; exit 1; fi; \
	 mv "$$tmp" "$$out"; echo "created $$out"; \
	 echo '[un-monthly-csv] uploadとElasticsearch投入は行いません。'

validate-csv:
	@test -n "$(FILES)" || { echo 'FILES="CSV ..."を指定してください。'; exit 1; }
	@ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url $(FILES)

upload-official: upload
	@jp_files=("$(DATA_DIR)"/jp-yearly-mstats2026-*.csv(Nom)); jp=$$jp_files[1]; \
	 jp_infant_files=("$(DATA_DIR)"/jp-infant-yearly-mstats2026-*.csv(Nom)); jp_infant=$$jp_infant_files[1]; \
	 us_files=("$(DATA_DIR)"/us-yearly-mstats2026-*.csv(Nom)); us=$$us_files[1]; \
	 test -n "$$jp" -a -n "$$jp_infant" -a -n "$$us" || { echo '日本年次・日本乳児年次・米国年次CSVのいずれかがありません。'; exit 1; }; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$jp" "$$jp_infant" "$$us"; \
	 echo '[upload-official] 最新の日本・米国年次CSVを$(SERVER)へ送ります。'; \
	 scp "$$jp" "$$jp_infant" "$$us" $(SERVER):$(SERVER_MSTATS_DIR)/data/; \
	 ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${jp:t} jp-yearly-mstats2026.csv && ln -sfn data/$${jp_infant:t} jp-infant-yearly-mstats2026.csv && ln -sfn data/$${us:t} us-yearly-mstats2026.csv"

upload-hmd:
	@files=("$(DATA_DIR)"/stmf-weekly-mstats2026-*.csv(Nom)); file=$$files[1]; \
	 test -n "$$file" || { echo 'HMD週次CSVがありません。'; exit 1; }; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$file"; \
	 scp "$$file" $(SERVER):$(SERVER_MSTATS_DIR)/data/; \
	 ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${file:t} stmf-weekly-mstats2026.csv"

upload-wpp:
	@files=("$(DATA_DIR)"/un-wpp-yearly-mstats2026-*.csv(Nom)); file=$$files[1]; \
	 test -n "$$file" || { echo 'WPP年次CSVがありません。'; exit 1; }; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$file"; \
	 scp "$$file" $(SERVER):$(SERVER_MSTATS_DIR)/data/; \
	 ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${file:t} un-wpp-yearly-mstats2026.csv"

upload-oecd:
	@files=("$(DATA_DIR)"/oecd-infant-yearly-mstats2026-*.csv(Nom)); file=$$files[1]; \
	 test -n "$$file" || { echo 'OECD乳児・周産期年次CSVがありません。'; exit 1; }; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$file"; \
	 scp "$$file" $(SERVER):$(SERVER_MSTATS_DIR)/data/; \
	 ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${file:t} oecd-infant-yearly-mstats2026.csv"

upload-un-monthly:
	@files=("$(DATA_DIR)"/un-monthly-mortality-mstats2026-*.csv(Nom)); file=$$files[1]; \
	 test -n "$$file" || { echo 'UN月次死亡CSVがありません。'; exit 1; }; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$file"; \
	 scp "$$file" $(SERVER):$(SERVER_MSTATS_DIR)/data/; \
	 ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${file:t} un-monthly-mortality-mstats2026.csv"

upload-confirmed:
	@pop_files=("$(DATA_DIR)"/jp-pop-cfm-legacy-mstats2026-*.csv(Nom)); pop=$$pop_files[1]; \
	 monthly_files=("$(DATA_DIR)"/jp-dcause-cfm-mstats2026-*.csv(Nom)); monthly=$$monthly_files[1]; \
	 yearly_files=("$(DATA_DIR)"/jp-yearly-cfm-mstats2026-*.csv(Nom)); yearly=$$yearly_files[1]; \
	 test -n "$$pop" -a -n "$$monthly" -a -n "$$yearly" || { echo '日本確定数CSVが不足しています。'; exit 1; }; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$pop" "$$monthly" "$$yearly"; \
	 scp "$$pop" "$$monthly" "$$yearly" $(SERVER):$(SERVER_MSTATS_DIR)/data/; \
	 ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${pop:t} jp-pop-cfm-legacy-mstats2026.csv && ln -sfn data/$${monthly:t} jp-dcause-cfm-mstats2026.csv && ln -sfn data/$${yearly:t} jp-yearly-cfm-mstats2026.csv"

upload-exdeaths-sample:
	@files=("$(DATA_DIR)"/exdeaths-weekly-national-mstats2026-*.csv(Nom)); file=$$files[1]; \
	 test -n "$$file" || { echo '全国短縮CSVがありません。'; exit 1; }; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$file"; \
	 scp "$$file" $(SERVER):$(SERVER_MSTATS_DIR)/data/; \
	 ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${file:t} exdeaths-weekly-national-mstats2026.csv"

upload-exdeaths:
	@files=("$(DATA_DIR)"/exdeaths-weekly-mstats2026-*.csv(Nom)); file=$$files[1]; \
	 test -n "$$file" || { echo '全地域CSVがありません。'; exit 1; }; \
	 ruby "$(ROOT)/bin/validate-mstats-csv.rb" --require-src-url "$$file"; \
	 scp "$$file" $(SERVER):$(SERVER_MSTATS_DIR)/data/; \
	 ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${file:t} exdeaths-weekly-mstats2026.csv"

upload-yearly: upload-official upload-wpp

upload-mstats-all: upload-official upload-hmd upload-wpp upload-oecd upload-un-monthly upload-confirmed upload-exdeaths

check-latest-id-collisions:
	@patterns=(jp-dcause-mstats2026 jp-pop-mstats2026 jp-dcause-weekly-mstats2026 jp-yearly-mstats2026 \
	  jp-infant-yearly-mstats2026 us-yearly-mstats2026 jp-pop-cfm-legacy-mstats2026 jp-dcause-cfm-mstats2026 \
	  jp-yearly-cfm-mstats2026 stmf-weekly-mstats2026 exdeaths-weekly-mstats2026 \
	  un-wpp-yearly-mstats2026 oecd-infant-yearly-mstats2026 un-monthly-mortality-mstats2026); \
	 files=(); for pattern in $$patterns; do candidates=("$(DATA_DIR)/$${pattern}-"*.csv(Nom)); \
	   (( $$#candidates )) || { echo "latest CSV is missing: $$pattern"; exit 1; }; files+=("$${candidates[1]}"); done; \
	 duplicates=$$(for file in $$files; do tail -n +2 "$$file" | cut -d, -f1; done | LC_ALL=C sort | uniq -d | head -20); \
	 [[ -z $$duplicates ]] || { echo "duplicate IDs across latest CSVs:"; print -r -- "$$duplicates"; exit 1; }; \
	 echo "latest CSV cross-validation=ok files=$$#files"

reset-mstats-index:
	@[[ "$(YEARLY_INDEX)" == mstats<-> ]] || { echo 'YEARLY_INDEXはmstatsに年月日等を続けた物理index名に限定します。'; exit 1; }; \
	 started=$$SECONDS; mapping="$(ROOT)/config/elasticsearch/mstats2026.json"; \
	 ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' "$$mapping"; \
	 scp "$$mapping" $(SERVER):$(SERVER_MSTATS_DIR)/mstats-index-mapping.json; \
	 ssh $(SERVER) 'index="$(YEARLY_INDEX)"; cred=/Users/magician/.config/mstats/espass.txt; user=$$(cut -d: -f1 "$$cred"); pass=$$(cut -d: -f2- "$$cred"); curl -fsS -u "$$user:$$pass" -X DELETE "http://127.0.0.1:9200/$$index" >/dev/null 2>&1 || true; curl -fsS -u "$$user:$$pass" -H "Content-Type: application/json" -X PUT "http://127.0.0.1:9200/$$index" --data-binary @/Users/magician/$(SERVER_MSTATS_DIR)/mstats-index-mapping.json'; \
	 echo; echo "[timing] index delete/create: $$((SECONDS - started))s"

check-mstats-index:
	@ssh $(SERVER) 'index="$(YEARLY_INDEX)"; cred=/Users/magician/.config/mstats/espass.txt; user=$$(cut -d: -f1 "$$cred"); pass=$$(cut -d: -f2- "$$cred"); curl -fsS -u "$$user:$$pass" "http://127.0.0.1:9200/$$index/_count"; echo; curl -fsS -u "$$user:$$pass" "http://127.0.0.1:9200/$$index/_mapping/field/age_85plus,age_100plus,age_85over,age_100over"; echo'

logstash-official: IMPORT_FILES=/Users/magician/$(SERVER_MSTATS_DIR)/jp-dcause-mstats2026.csv /Users/magician/$(SERVER_MSTATS_DIR)/jp-pop-mstats2026.csv /Users/magician/$(SERVER_MSTATS_DIR)/jp-dcause-weekly-mstats2026.csv /Users/magician/$(SERVER_MSTATS_DIR)/jp-yearly-mstats2026.csv /Users/magician/$(SERVER_MSTATS_DIR)/jp-infant-yearly-mstats2026.csv /Users/magician/$(SERVER_MSTATS_DIR)/us-yearly-mstats2026.csv
logstash-hmd: IMPORT_FILES=/Users/magician/$(SERVER_MSTATS_DIR)/stmf-weekly-mstats2026.csv
logstash-wpp: IMPORT_FILES=/Users/magician/$(SERVER_MSTATS_DIR)/un-wpp-yearly-mstats2026.csv
logstash-oecd: IMPORT_FILES=/Users/magician/$(SERVER_MSTATS_DIR)/oecd-infant-yearly-mstats2026.csv
logstash-un-monthly: IMPORT_FILES=/Users/magician/$(SERVER_MSTATS_DIR)/un-monthly-mortality-mstats2026.csv
logstash-confirmed: IMPORT_FILES=/Users/magician/$(SERVER_MSTATS_DIR)/jp-pop-cfm-legacy-mstats2026.csv /Users/magician/$(SERVER_MSTATS_DIR)/jp-dcause-cfm-mstats2026.csv /Users/magician/$(SERVER_MSTATS_DIR)/jp-yearly-cfm-mstats2026.csv
logstash-exdeaths-sample: IMPORT_FILES=/Users/magician/$(SERVER_MSTATS_DIR)/exdeaths-weekly-national-mstats2026.csv
logstash-exdeaths: IMPORT_FILES=/Users/magician/$(SERVER_MSTATS_DIR)/exdeaths-weekly-mstats2026.csv
logstash-official logstash-hmd logstash-wpp logstash-oecd logstash-un-monthly logstash-confirmed logstash-exdeaths-sample logstash-exdeaths:
	@echo '[$@] $(YEARLY_INDEX)へ投入します。'; \
	 for file in $(IMPORT_FILES); do \
	   resolved=$$(ssh $(SERVER) "readlink -f '$$file'"); test -n "$$resolved" || { echo "cannot resolve $$file"; exit 1; }; \
	   run_id=$$(date +%s); started=$$SECONDS; \
	   echo "[$@] $${file:t}"; \
	   ssh -tt $(SERVER) "sudo systemctl stop logstash; sudo sh -c 'cred=/Users/magician/.config/mstats/espass.txt; export MSTATS_ES_USER=\$$(cut -d: -f1 \"\$$cred\"); export ES_PASSWORD=\$$(cut -d: -f2- \"\$$cred\"); export MSTATS_YEARLY_INDEX=$(YEARLY_INDEX); export MSTATS_IMPORT_PATH=$$resolved; exec $(LOGSTASH) --path.settings /etc/logstash --path.data /tmp/mstats-import-$$run_id -w 1 -f /Users/magician/$(SERVER_MSTATS_DIR)/mstats-import.conf'"; \
	   echo "[timing] $${file:t}: $$((SECONDS - started))s"; \
	 done

switch-mstats-alias:
	@echo '[switch-mstats-alias] mstats aliasを$(YEARLY_INDEX)へatomicに切替えます。'; \
	 ssh $(SERVER) "sh /Users/magician/$(SERVER_MSTATS_DIR)/switch-mstats-alias.sh $(YEARLY_INDEX)"

upload:
	@pop_files=("$(DATA_DIR)"/jp-pop-mstats2026-*.csv(Nom)); pop=$$pop_files[1]; \
	 death_files=("$(DATA_DIR)"/jp-dcause-mstats2026-*.csv(Nom)); death=$$death_files[1]; \
	 weekly_files=("$(DATA_DIR)"/jp-dcause-weekly-mstats2026-*.csv(Nom)); weekly=$$weekly_files[1]; \
	 test -n "$$pop" -a -n "$$death" -a -n "$$weekly"; \
	 mkdir -p "$(STATE_DIR)"; log="$(STATE_DIR)/upload.log"; \
	 echo '[upload] 最新の人口・月次死因・週次死因CSVを$(SERVER)へ送ります。'; \
	 if ! { scp "$$pop" "$$death" "$$weekly" $(SERVER):$(SERVER_MSTATS_DIR)/data/ && ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${death:t} jp-dcause-mstats2026.csv && ln -sfn data/$${weekly:t} jp-dcause-weekly-mstats2026.csv && ln -sfn data/$${pop:t} jp-pop-mstats2026.csv"; } > "$$log" 2>&1; then cat "$$log"; exit 1; fi

logstash:
	@mkdir -p "$(STATE_DIR)"; log="$(STATE_DIR)/logstash.log"; \
	 echo '[logstash] $(SERVER)のmstats2026.confでCSVを投入します。'; \
	 if ! ssh -tt $(SERVER) "sudo systemctl stop logstash; sudo sh -c 'cred=/Users/magician/.config/mstats/espass.txt; export MSTATS_ES_USER=\$$(cut -d: -f1 \"\$$cred\"); export ES_PASSWORD=\$$(cut -d: -f2- \"\$$cred\"); exec $(LOGSTASH) --path.settings /etc/logstash -w 1 -r -f /Users/magician/$(SERVER_MSTATS_DIR)/mstats2026.conf'" > "$$log" 2>&1; then cat "$$log"; exit 1; fi

cod codtr:
	@echo '[$@] 手元の原CSVからCSVを生成し、必要時のみ投入します。Codexは起動しません。'
	@$(MAKE) --no-print-directory csv
	@if test -f "$(STATE_DIR)/csv-updated"; then \
	  $(MAKE) --no-print-directory upload logstash; \
	 fi
