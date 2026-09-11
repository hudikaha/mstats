SHELL := /bin/zsh
.SHELLFLAGS := -eu -o pipefail -c

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
WEB_DIR := $(ROOT)/web
WEB_FILES := kcor.rb kcor.js kcor.css vdeath.rb vdeathmiss.rb afterdose.rb
LIB_DIR := $(ROOT)/lib
LIB_FILES := missing_history.rb

SERVER ?= fujikawa.org
SERVER_WEB_DIR ?= fujikawa/covid19
RSYNC ?= rsync
RSYNC_FLAGS ?= -rci --no-perms --itemize-changes

.PHONY: all help check dry-run upload

all: upload

help:
	@echo 'make           変更されたKCOR Web fileだけを検査・配備'
	@echo 'make dry-run   本番との差を表示（配備しない）'
	@echo 'make check     RubyとJavaScriptの構文を検査'
	@echo 'make upload    checksumが異なるfileだけを配備'

check:
	@ruby -c "$(WEB_DIR)/kcor.rb"
	@ruby -c "$(WEB_DIR)/vdeath.rb"
	@ruby -c "$(WEB_DIR)/vdeathmiss.rb"
	@ruby -c "$(WEB_DIR)/afterdose.rb"
	@node --check "$(WEB_DIR)/kcor.js"
	@ruby -c "$(LIB_DIR)/missing_history.rb"
	@ruby "$(ROOT)/test/test_missing_history.rb"

dry-run: check
	@cd "$(WEB_DIR)" && \
	 $(RSYNC) $(RSYNC_FLAGS) --dry-run $(WEB_FILES) "$(SERVER):$(SERVER_WEB_DIR)/"
	@cd "$(LIB_DIR)" && \
	 $(RSYNC) $(RSYNC_FLAGS) --dry-run $(LIB_FILES) "$(SERVER):$(SERVER_WEB_DIR)/lib/"

upload: check
	@cd "$(WEB_DIR)" && \
	 $(RSYNC) $(RSYNC_FLAGS) $(WEB_FILES) "$(SERVER):$(SERVER_WEB_DIR)/"
	@cd "$(LIB_DIR)" && \
	 $(RSYNC) $(RSYNC_FLAGS) $(LIB_FILES) "$(SERVER):$(SERVER_WEB_DIR)/lib/"
	@ssh "$(SERVER)" 'cd "$(SERVER_WEB_DIR)" && ruby -c kcor.rb && ruby -c vdeath.rb && ruby -c vdeathmiss.rb && ruby -c afterdose.rb && ruby -c lib/missing_history.rb'

# 検証版だけを検査・配備する。正式版の配備targetには含めない。
# Check/deploy only the trial page; keep it out of the formal upload target.
.PHONY: vdeath2-check vdeath2-upload vdeath2-dom-check
vdeath2-check:
	@ruby -c "$(WEB_DIR)/vdeath2.rb"
	@ruby -c "$(ROOT)/test/test_vdeath2.rb"
	@ruby "$(ROOT)/test/test_vdeath2.rb"

vdeath2-upload: vdeath2-check
	@scp "$(WEB_DIR)/vdeath2.rb" "$(SERVER):$(SERVER_WEB_DIR)/vdeath2.rb.new"
	@ssh "$(SERVER)" 'cd "$(SERVER_WEB_DIR)" && ruby -c vdeath2.rb.new && chmod 755 vdeath2.rb.new && mv vdeath2.rb.new vdeath2.rb'

vdeath2-dom-check:
	@node "$(ROOT)/test/test_vdeath2_dom.js"
