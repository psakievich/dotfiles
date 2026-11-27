# tools/ -- one Spack environment: build -> buildcache -> deploy from the cache.
#
# Independent of the dotfiles. The only connection is the generated load.sh,
# which a shell sources (`make link LINK=$DOTFILES/env.sh`).
#
#   make            build + deploy
#   make build      concretize, install and push to the buildcache
#   make deploy     install from the buildcache into DOT_RUNTIME_ROOT, write load.sh
#   make link LINK=<path>   symlink <path> to load.sh
#   make gc         uninstall runtime packages the deployment no longer needs
#   make clean      force a re-concretize on the next build
#   make build-wipe / runtime-wipe
TOOLS_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/
.DEFAULT_GOAL := all

# gitignored, machine-local overrides (DOT_BUILD_ROOT, ENV_TEMPLATE, ...)
-include $(TOOLS_DIR)local.mk

# ── Locations ────────────────────────────────────────────────────────
#   DOT_BUILD_ROOT    spack clone, padded build tree, stage, caches, build env,
#                     buildcache. Disposable; point it at scratch if HOME is small.
#   DOT_RUNTIME_ROOT  runtime-only install tree (opt/), view/ and load.sh.
#                     Deleting the build root does not break it.
DOT_BUILD_ROOT   ?= $(TOOLS_DIR).build
DOT_RUNTIME_ROOT ?= $(HOME)/.local/opt/dotfiles

# Sourcing any spack's setup-env.sh exports SPACK_ROOT; don't let that silently
# redirect the build. Set SPACK_ROOT in local.mk or on the command line instead.
ifeq ($(origin SPACK_ROOT),environment)
SPACK_ROOT    := $(DOT_BUILD_ROOT)/spack
endif
SPACK_ROOT    ?= $(DOT_BUILD_ROOT)/spack
SPACK_VERSION ?= develop
SPACK_URL     ?= https://github.com/spack/spack
BUILDCACHE    ?= $(DOT_BUILD_ROOT)/buildcache
ENV_TEMPLATE  ?= $(TOOLS_DIR)spack.yaml
CONFIG_ROOT   ?= $(TOOLS_DIR)configs
PYTHON        ?= python3

BUILD_ENV  := $(DOT_BUILD_ROOT)/env
DEPLOY_ENV := $(DOT_BUILD_ROOT)/deploy
VIEW       := $(DOT_RUNTIME_ROOT)/view
LOAD_SH    := $(DOT_RUNTIME_ROOT)/load.sh

# The config scopes (configs/*/config.yaml) read the roots from these. They
# can't use DOT_*_ROOT: Spack unsets every *_ROOT variable (except SPACK_ROOT)
# in the build process, which resolves build_stage and the caches.
export DOTSPACK_BUILD   := $(DOT_BUILD_ROOT)
export DOTSPACK_RUNTIME := $(DOT_RUNTIME_ROOT)
# nothing should fall back to ~/.spack
export SPACK_DISABLE_LOCAL_CONFIG := 1
export SPACK_USER_CACHE_PATH := $(DOT_BUILD_ROOT)/user-cache

SPACK         := $(SPACK_ROOT)/bin/spack
SPACK_BUILD   := $(SPACK) -C $(CONFIG_ROOT)/common -C $(CONFIG_ROOT)/build
SPACK_RUNTIME := $(SPACK) -C $(CONFIG_ROOT)/common -C $(CONFIG_ROOT)/runtime

.PHONY: all deps update-deps build concretize deploy link gc clean build-wipe runtime-wipe

all: build deploy

print-%:
	@echo $($(*))

# ── Spack clone ──────────────────────────────────────────────────────
deps: $(SPACK_ROOT)

$(SPACK_ROOT):
	git clone --depth 1 --branch $(SPACK_VERSION) $(SPACK_URL) $@
	$(@)/bin/spack repo set --scope site --destination '$$spack/etc/spack-packages' builtin
	$(@)/bin/spack bootstrap root --scope site '$$spack/etc/bootstrap'

update-deps:
	cd $(SPACK_ROOT) && git fetch --depth 1 origin $(SPACK_VERSION) && git checkout FETCH_HEAD

# ── Build (DOT_BUILD_ROOT) ───────────────────────────────────────────
# spack.yaml -> spack.lock -> install + push to the buildcache (.cached).
# The build tree uses padded_length so binaries relocate into any runtime path.
build: $(BUILD_ENV)/.cached
concretize: $(BUILD_ENV)/spack.lock

$(BUILD_ENV)/spack.yaml: $(ENV_TEMPLATE) | $(SPACK_ROOT)
	rm -rf $(BUILD_ENV)
	$(SPACK_BUILD) env create -d $(BUILD_ENV) $(ENV_TEMPLATE)

$(BUILD_ENV)/spack.lock: $(BUILD_ENV)/spack.yaml
	$(SPACK_BUILD) -e $(BUILD_ENV) concretize

$(BUILD_ENV)/.cached: $(BUILD_ENV)/spack.lock
	$(SPACK_BUILD) -e $(BUILD_ENV) install
	$(SPACK_BUILD) -e $(BUILD_ENV) buildcache push --unsigned --update-index $(BUILDCACHE)
	touch $(@)

# ── Deploy (DOT_RUNTIME_ROOT) ────────────────────────────────────────
# A small env include-concretes the build env and installs its link/run
# closure from the buildcache only: no compiling, no build deps. load.sh only
# references the view, so the build root can be wiped afterwards.
deploy: $(LOAD_SH)

$(LOAD_SH): $(BUILD_ENV)/.cached
	rm -rf $(DEPLOY_ENV)
	mkdir -p $(DOT_RUNTIME_ROOT)
	$(SPACK_RUNTIME) env create -d --with-view $(VIEW) --include-concrete $(BUILD_ENV) $(DEPLOY_ENV)
	$(SPACK_RUNTIME) -e $(DEPLOY_ENV) mirror add --unsigned dotbuild $(BUILDCACHE)
	$(SPACK_RUNTIME) -e $(DEPLOY_ENV) concretize
	$(SPACK_RUNTIME) -e $(DEPLOY_ENV) install --use-buildcache only
	$(SPACK_RUNTIME) env activate --sh $(DEPLOY_ENV) | $(PYTHON) $(TOOLS_DIR)lib/make_load_sh.py > $(@).tmp
	mv $(@).tmp $(@)

# Point a file some shell sources (e.g. $DOTFILES/env.sh) at load.sh.
# An existing symlink is replaced; a regular file is left alone.
link:
	$(if $(LINK),,$(error usage: make link LINK=<path>, e.g. LINK=$$DOTFILES/env.sh))
	@if [ -e '$(LINK)' ] && [ ! -L '$(LINK)' ]; then \
	  echo "$(LINK) exists and is not a symlink; not replacing it" >&2; exit 1; fi
	ln -sfn $(LOAD_SH) $(LINK)

# Uninstall runtime packages the deployment no longer needs. `spack gc -e`
# keeps only an env's *own* roots and ignores include_concrete, so protect
# the build env's roots (exactly what the view holds), not the deploy env's.
gc:
	$(if $(wildcard $(LOAD_SH)),,$(error nothing is deployed in $(DOT_RUNTIME_ROOT); use runtime-wipe instead))
	$(SPACK_RUNTIME) gc -y -e $(BUILD_ENV)

# ── Cleanup ──────────────────────────────────────────────────────────
clean:
	rm -f $(BUILD_ENV)/spack.lock $(BUILD_ENV)/.cached

build-wipe:
	rm -rf $(DOT_BUILD_ROOT)

runtime-wipe:
	rm -rf $(DOT_RUNTIME_ROOT) $(DEPLOY_ENV)
