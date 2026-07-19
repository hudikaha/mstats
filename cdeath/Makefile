SHELL := /bin/zsh
.SHELLFLAGS := -eu -o pipefail -c

# Target flow
#
#   make (default) -> help
#   check          -> source-month checks -> temporary pop/death conversion -> CSV checks
#   csv            -> source-month checks -> manifest comparison
#                     -> changed: timestamped pop/death CSV creation and checks
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
STMF_DIR ?= $(ROOT)/src/stmf
STMF_SOURCE ?= $(STMF_DIR)/stmf.csv
DATA_DIR ?= $(ROOT)/out
STATE_DIR ?= $(ROOT)/tmp/make

POP_URL := https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200524&tstat=000000090001&cycle=1&tclass1=000001011678&cycle_facet=tclass1&tclass2val=0
DCAUSE_URL := https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450011&tstat=000001028897&cycle=1&tclass1=000001053058&tclass2=000001053060&tclass3val=0

SERVER ?= fujikawa.org
SERVER_MSTATS_DIR ?= mstats
SERVER_WEB_DIR ?= fujikawa/covid19
LOGSTASH ?= /usr/share/logstash/bin/logstash
CODEX ?= codex

.PHONY: help all fetch fetch-pop fetch-death fetch-stmf check csv mort-csv stmf-csv upload logstash cod codtr

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
  [[ $$header == id,loc_code,location,yearmonth,category,*age_junior ]] || { echo "wrong mstats2026 header: $$file"; return 1; }; \
  rows=$$(( $$(wc -l < "$$file") - 1 )); (( rows > 0 )) || { echo "no data rows: $$file"; return 1; }; \
  duplicates=$$(tail -n +2 "$$file" | cut -d, -f1 | LC_ALL=C sort | uniq -d); \
  [[ -z $$duplicates ]] || { echo "duplicate ids: $$file"; return 1; }; \
  awk -F, -v category="$$category" 'NR > 1 && $$5 != category { exit 1 }' "$$file" || { echo "wrong category: $$file"; return 1; }; \
  if [[ $$category == pop ]]; then \
    awk -F, 'NR > 1 && ($$15 == "" || $$21 == "") { exit 1 }' "$$file" || { echo "missing core population value: $$file"; return 1; }; \
  fi; \
  periods=$$(tail -n +2 "$$file" | cut -d, -f4 | LC_ALL=C sort -u); \
  first=$$(print -r -- "$$periods" | head -1); last=$$(print -r -- "$$periods" | tail -1); \
  echo "$$category: rows=$$rows periods=$$(print -r -- "$$periods" | wc -l | tr -d ' ') ($$first..$$last)"; \
}
endef

help:
	@echo 'make check    原CSVの月抜けと変換結果を検証'
	@echo 'make fetch    Codexで人口・死因の次月公開確認と取得（既存CSVは検証しない）'
	@echo 'make fetch-pop   Codexで人口の新規原CSVを取得'
	@echo 'make fetch-death Codexで死因の新規原CSVを取得'
	@echo 'make fetch-stmf HMD認証情報を環境変数から読みSTMF pooled CSVを取得'
	@echo 'make all      Codexで取得後、CSV生成・必要時のみ投入'
	@echo 'make csv      新規・更新原CSVがある場合だけ日時付き累積CSVを生成'
	@echo 'make mort-csv 最新の月次CSVからmort.rb用週次CSVを生成（投入しない）'
	@echo 'make stmf-csv STMF pooled CSVをmstats2026週次CSVへ変換（投入しない）'
	@echo 'make cod      CSV更新があればサーバへ送りLogstashで投入'
	@echo 'make codtr    make codと同じデータ更新（codtr.rbは年未完の月も表示）'
	@echo 'make upload   最新の2つのCSVをサーバへ送って固定名リンクを更新'
	@echo 'make logstash サーバ上でmstats2026.confを一回実行'

fetch: fetch-pop fetch-death

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
	 $(VALIDATE_MONTHS); $(VALIDATE_CSV); \
	 validate_months pop "$${pop_sources[@]}" || exit 1; validate_months death "$${death_sources[@]}" || exit 1; \
	 for file in "$${pop_sources[@]}"; do shasum -a 256 "$$file"; done | LC_ALL=C sort > "$(STATE_DIR)/pop.current"; \
	 for file in "$${death_sources[@]}"; do shasum -a 256 "$$file"; done | LC_ALL=C sort > "$(STATE_DIR)/death.current"; \
	 changed=0; stamp=$$(date +%Y%m%d-%H%M%S); \
	 if ! cmp -s "$(STATE_DIR)/pop.current" "$(STATE_DIR)/pop.sources"; then \
	    echo '[csv] 人口の日時付き累積CSVを生成します。'; \
	    tmp="$(DATA_DIR)/.jp-pop-mstats2026-$$stamp.csv.tmp"; out="$(DATA_DIR)/jp-pop-mstats2026-$$stamp.csv"; \
	    if ! ruby "$(ROOT)/import/jp-pop.rb" "$${pop_sources[@]}" > "$$tmp" 2> "$(STATE_DIR)/jp-pop.log"; then cat "$(STATE_DIR)/jp-pop.log"; exit 1; fi; \
	    validate_csv pop "$$tmp"; mv "$$tmp" "$$out"; \
	    cp "$(STATE_DIR)/pop.current" "$(STATE_DIR)/pop.sources"; echo "created $$out"; changed=1; \
	  fi; \
	 if ! cmp -s "$(STATE_DIR)/death.current" "$(STATE_DIR)/death.sources"; then \
	    echo '[csv] 死因の日時付き累積CSVを生成します。'; \
	    tmp="$(DATA_DIR)/.jp-dcause-mstats2026-$$stamp.csv.tmp"; out="$(DATA_DIR)/jp-dcause-mstats2026-$$stamp.csv"; \
	    if ! ruby "$(ROOT)/import/jp-dcause.rb" "$${death_sources[@]}" > "$$tmp" 2> "$(STATE_DIR)/jp-dcause.log"; then cat "$(STATE_DIR)/jp-dcause.log"; exit 1; fi; \
	    validate_csv death "$$tmp"; mv "$$tmp" "$$out"; \
	    cp "$(STATE_DIR)/death.current" "$(STATE_DIR)/death.sources"; echo "created $$out"; changed=1; \
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
	 [[ $$header == id,loc_code,location,yearweek,category,*age_50_64 ]] || { echo "wrong weekly mstats2026 header: $$tmp"; rm -f "$$tmp"; exit 1; }; \
	 rows=$$(( $$(wc -l < "$$tmp") - 1 )); (( rows > 0 )) || { echo "no weekly data rows: $$tmp"; rm -f "$$tmp"; exit 1; }; \
	 duplicates=$$(tail -n +2 "$$tmp" | cut -d, -f1 | LC_ALL=C sort | uniq -d | head -1); \
	 [[ -z $$duplicates ]] || { echo "duplicate weekly id: $$duplicates"; rm -f "$$tmp"; exit 1; }; \
	 periods=$$(tail -n +2 "$$tmp" | cut -d, -f4 | LC_ALL=C sort -u); \
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
	 periods=$$(tail -n +2 "$$tmp" | cut -d, -f4 | LC_ALL=C sort -u); \
	 first=$$(print -r -- "$$periods" | head -1); last=$$(print -r -- "$$periods" | tail -1); \
	 mv "$$tmp" "$$out"; \
	 echo "created $$out: rows=$$rows periods=$$(print -r -- "$$periods" | wc -l | tr -d ' ') ($$first..$$last)"; \
	 echo '[stmf-csv] uploadとElasticsearch投入はまだ行いません。'

upload:
	@pop_files=("$(DATA_DIR)"/jp-pop-mstats2026-*.csv(Nom)); pop=$$pop_files[1]; \
	 death_files=("$(DATA_DIR)"/jp-dcause-mstats2026-*.csv(Nom)); death=$$death_files[1]; \
	 test -n "$$pop" -a -n "$$death"; \
	 mkdir -p "$(STATE_DIR)"; log="$(STATE_DIR)/upload.log"; \
	 echo '[upload] 最新の人口・死因CSVを$(SERVER)へ送ります。'; \
	 if ! { scp "$$pop" "$$death" $(SERVER):$(SERVER_MSTATS_DIR)/data/ && ssh $(SERVER) "cd $(SERVER_MSTATS_DIR) && ln -sfn data/$${death:t} jp-dcause-mstats2026.csv && ln -sfn data/$${pop:t} jp-pop-mstats2026.csv"; } > "$$log" 2>&1; then cat "$$log"; exit 1; fi

logstash:
	@mkdir -p "$(STATE_DIR)"; log="$(STATE_DIR)/logstash.log"; \
	 echo '[logstash] $(SERVER)のmstats2026.confでCSVを投入します。'; \
	 if ! ssh -tt $(SERVER) 'sudo systemctl stop logstash; sudo $(LOGSTASH) --path.settings /etc/logstash -w 1 -r -f ~/$(SERVER_MSTATS_DIR)/mstats2026.conf' > "$$log" 2>&1; then cat "$$log"; exit 1; fi

cod codtr:
	@echo '[$@] 手元の原CSVからCSVを生成し、必要時のみ投入します。Codexは起動しません。'
	@$(MAKE) --no-print-directory csv
	@if test -f "$(STATE_DIR)/csv-updated"; then \
	  $(MAKE) --no-print-directory upload logstash; \
	 fi
