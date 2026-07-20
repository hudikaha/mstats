SHELL := /bin/zsh
.SHELLFLAGS := -eu -c

SRC_DIR ?= /Users/magician/icloud/vdeath/src
OUT_DIR ?= ../outputs
RUBY ?= ruby
SCRIPT := ./vdeathp.rb
RUN := $(RUBY) $(SCRIPT)
AGES := 00-09,10-19,20-29,30-39,40-49,50-59,60-69,70-79,80-89,90-99,100+,80+,all
CITIES := jp132101 jp141500 jp221309 jp222267 jp232068 jp232076 jp271004 jp442054
comma := ,

.PHONY: all $(CITIES)
all: $(CITIES)

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
	if [[ "$(7)" == yes ]] && needs "$(OUT_DIR)/$(2)_PY.csv"; then \
	  $(RUN) personyear --headers "$$$$headers" --steps 1,3,6,all --ages "$(AGES)" $$$$opts --output "$(OUT_DIR)/$(2)_PY.csv" $$$$inputs || exit $$$$?; \
	fi; \
	if [[ "$(7)" == yes ]] && needs "$(OUT_DIR)/$(2)_PY-WKD.csv"; then \
	  $(RUN) afterdose --headers "$$$$headers" --weeks 1-99 --ages 80+,all $$$$opts --output "$(OUT_DIR)/$(2)_PY-WKD.csv" $$$$inputs || exit $$$$?; \
	fi; \
	if needs "$(OUT_DIR)/$(2)_CUMD-WK.csv"; then \
	  $(RUN) kcor --headers "$$$$headers" $$$$opts --output "$(OUT_DIR)/$(2)_CUMD-WK.csv" $$$$inputs || exit $$$$?; \
	fi; \
	if needs "$(OUT_DIR)/$(2)_$(6).csv"; then \
	  $(RUN) anonymize --headers "$$$$headers" $$$$opts --output "$(OUT_DIR)/$(2)_$(6).csv" $$$$inputs || exit $$$$?; \
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
