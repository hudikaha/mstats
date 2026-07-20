SHELL := /bin/zsh
.SHELLFLAGS := -eu -o pipefail -c

WEB_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
WEB_RB := $(sort $(shell cd "$(WEB_DIR)" && printf '%s\n' *.rb))
WEB_FILES := $(WEB_RB) mfacts.css
WEB_DIRS := content qr
DEPLOY_ITEMS := $(WEB_FILES) $(WEB_DIRS)
REDIRECT_DIR := $(WEB_DIR)/redirects
REDIRECT_FILES := $(sort $(shell cd "$(REDIRECT_DIR)" && printf '%s\n' *.html))

SERVER ?= fujikawa.org
SERVER_WEB_DIR ?= fujikawa/covid19
RSYNC ?= rsync
RSYNC_FLAGS ?= -rci --no-perms --itemize-changes

.PHONY: all help check dry-run upload

all: upload

help:
	@echo 'make           変更されたweb fileだけを検査・配備'
	@echo 'make dry-run   本番との差を表示（配備しない）'
	@echo 'make check     web/*.rbの構文を検査'
	@echo 'make upload    checksumが異なるfileだけを配備'

check:
	@for file in $(WEB_RB); do \
	  ruby -c "$(WEB_DIR)/$$file" >/dev/null; \
	done
	@echo 'Ruby syntax OK: $(words $(WEB_RB)) files'

dry-run: check
	@cd "$(WEB_DIR)" && \
	 $(RSYNC) $(RSYNC_FLAGS) --dry-run $(DEPLOY_ITEMS) "$(SERVER):$(SERVER_WEB_DIR)/"
	@cd "$(REDIRECT_DIR)" && \
	 $(RSYNC) $(RSYNC_FLAGS) --dry-run $(REDIRECT_FILES) "$(SERVER):$(SERVER_WEB_DIR)/"

upload: check
	@cd "$(WEB_DIR)" && \
	 $(RSYNC) $(RSYNC_FLAGS) $(DEPLOY_ITEMS) "$(SERVER):$(SERVER_WEB_DIR)/"
	@cd "$(REDIRECT_DIR)" && \
	 $(RSYNC) $(RSYNC_FLAGS) $(REDIRECT_FILES) "$(SERVER):$(SERVER_WEB_DIR)/"
	@ssh "$(SERVER)" 'cd "$(SERVER_WEB_DIR)" && \
	  for file in $(WEB_RB); do ruby -c "$$file" >/dev/null; done'
	@echo 'Remote Ruby syntax OK: $(words $(WEB_RB)) files'
