_INTERNAL_MK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/
.DEFAULT_GOAL := all

# ── Locations ────────────────────────────────────────────────────────
# Three roots, kept apart so HOME only ever holds config + runtime binaries:
#
#   $(DOTFILES)          this repo: configuration only
#   DOT_BUILD_ROOT       spack clone, build install tree, stage, caches,
#                        build environments, buildcache. Point it at scratch
#                        space when HOME is small; it is safe to delete.
#   DOT_RUNTIME_ROOT     deployments: a shared runtime-only install tree
#                        (from the buildcache) plus, per deployed env, a view
#                        and load.sh. This is what the shell uses.
#
# Both can be overridden from the environment or the make command line.
DOT_BUILD_ROOT   ?= $(_INTERNAL_MK_DIR).build
DOT_RUNTIME_ROOT ?= $(HOME)/.local/opt/dotfiles

# Sourcing any spack's setup-env.sh exports SPACK_ROOT; don't let that silently
# redirect the build. Set SPACK_ROOT in a Makefile or on the command line instead.
ifeq ($(origin SPACK_ROOT),environment)
SPACK_ROOT     := $(DOT_BUILD_ROOT)/spack
endif
SPACK_ROOT     ?= $(DOT_BUILD_ROOT)/spack
SPACK_DIR      ?= $(SPACK_ROOT)
SPACK_ENV_ROOT ?= $(DOT_BUILD_ROOT)/envs
BUILDCACHE     ?= $(DOT_BUILD_ROOT)/buildcache
DEPLOY_ENV_ROOT ?= $(DOT_BUILD_ROOT)/deploy
ACTIVE_FILE    ?= $(DOT_RUNTIME_ROOT)/active
CONFIG_ROOT    ?= $(_INTERNAL_MK_DIR)configs
TEMPLATE_ROOT  ?= spack_environments
PYTHON         ?= python3

# Include-concrete chain, declared as `<env>_PARENT = <parent env(s)>` before
# this file is included. Rules are generated at the bottom of this file.
PARENT_VARS := $(filter %_PARENT,$(.VARIABLES))
ALL_PARENTS := $(sort $(foreach V,$(PARENT_VARS),$($(V))))

# Envs that `make deploy` (and `make all`) deploy, in shell load order: each
# load.sh prepends, so later entries take precedence. A deployment contains
# its env plus everything it include-concretes, so the leaves are enough by
# default. Any built env can also be deployed on its own: make deploy-<env>
DEPLOY ?= $(filter-out $(ALL_PARENTS),$(ENVS))

# an env plus all of its (transitive) parents
env-closure = $(foreach E,$(1),$(E) $(call env-closure,$($(E)_PARENT)))

# deployments that currently exist under DOT_RUNTIME_ROOT
DEPLOYED = $(patsubst $(DOT_RUNTIME_ROOT)/%/load.sh,%,$(wildcard $(DOT_RUNTIME_ROOT)/*/load.sh))

# Spack config scopes reference these, and nothing should fall back to ~/.spack
export DOT_BUILD_ROOT DOT_RUNTIME_ROOT
export SPACK_DISABLE_LOCAL_CONFIG := 1
export SPACK_USER_CACHE_PATH := $(DOT_BUILD_ROOT)/user-cache

include $(_INTERNAL_MK_DIR)deps.mk

SPACK         := $(SPACK_ROOT)/bin/spack
SPACK_BUILD   := $(SPACK) -C $(CONFIG_ROOT)/common -C $(CONFIG_ROOT)/build
SPACK_RUNTIME := $(SPACK) -C $(CONFIG_ROOT)/common -C $(CONFIG_ROOT)/runtime

BUILD_SENTINELS := $(foreach E, $(ENVS), $(SPACK_ENV_ROOT)/$(E)/.cached)

.PRECIOUS: $(SPACK_ENV_ROOT)/%/spack.yaml $(SPACK_ENV_ROOT)/%/spack.lock $(SPACK_ENV_ROOT)/%/.cached \
	$(DOT_RUNTIME_ROOT)/%/load.sh

.PHONY: all build deploy runtime-gc _runtime-gc clean wipe build-wipe runtime-wipe stow unstow $(ENVS)

all: build deploy
build: $(ENVS)

clean:
	$(info does nothing right now)

print-%:
	@echo $($(*))

# ── Build stage (scratch) ────────────────────────────────────────────
# <env>/spack.yaml -> spack.lock -> install + push to buildcache (.cached)
$(ENVS): %: $(SPACK_ENV_ROOT)/%/.cached
	$(info $(*) built and cached)

$(SPACK_ENV_ROOT)/%/.cached: $(SPACK_ENV_ROOT)/%/spack.lock
	$(SPACK_BUILD) -e $(SPACK_ENV_ROOT)/$(*) install
	$(SPACK_BUILD) -e $(SPACK_ENV_ROOT)/$(*) buildcache push --unsigned --update-index $(BUILDCACHE)
	touch $(@)

$(SPACK_ENV_ROOT)/%/spack.lock: $(SPACK_ENV_ROOT)/%/spack.yaml
	$(SPACK_BUILD) -e $(SPACK_ENV_ROOT)/$(*) concretize

$(SPACK_ENV_ROOT)/%/spack.yaml: $(TEMPLATE_ROOT)/%/spack.yaml | $(SPACK_DIR)
	rm -rf $(SPACK_ENV_ROOT)/$(*)
	$(SPACK_BUILD) env create -d $(SPACK_ENV_ROOT)/$(*) $(<)

# Usage: $(eval $(call env-depends-on,<env>,<parent-env(s)>))
# Generates a spack.yaml rule that uses --include-concrete to inherit
# concretization from parent environment(s). Prefer declaring
# `<env>_PARENT = <parent>` instead; the rule is then generated for you.
define env-depends-on
$(SPACK_ENV_ROOT)/$(1)/spack.yaml: $(foreach P,$(2),$(SPACK_ENV_ROOT)/$(P)/spack.lock) $(TEMPLATE_ROOT)/$(1)/spack.yaml | $(SPACK_DIR)
	rm -rf $(SPACK_ENV_ROOT)/$(1)
	$$(SPACK_BUILD) env create -d $(foreach P,$(2),--include-concrete $(SPACK_ENV_ROOT)/$(P)) $(SPACK_ENV_ROOT)/$(1) $(TEMPLATE_ROOT)/$(1)/spack.yaml
endef

# ── Deploy stage (HOME) ──────────────────────────────────────────────
# deploy-<env>: a small env (in the build root) that include-concretes the
# <env> build env, installs its link/run closure from the buildcache only (no
# build deps, no compiling) into the shared runtime install tree, and keeps
# its own view at DOT_RUNTIME_ROOT/<env>/view. load.sh only references that
# view, so DOT_BUILD_ROOT can be wiped without breaking the shell.
deploy: $(foreach E, $(DEPLOY), deploy-$(E))
	printf '%s\n' $(DEPLOY) > $(ACTIVE_FILE)

deploy-%: $(DOT_RUNTIME_ROOT)/%/load.sh
	$(info $(*) deployed to $(DOT_RUNTIME_ROOT)/$(*))

$(DOT_RUNTIME_ROOT)/%/load.sh: $(SPACK_ENV_ROOT)/%/.cached
	rm -rf $(DEPLOY_ENV_ROOT)/$(*)
	mkdir -p $(DOT_RUNTIME_ROOT)/$(*)
	$(SPACK_RUNTIME) env create -d --with-view $(DOT_RUNTIME_ROOT)/$(*)/view \
	  --include-concrete $(SPACK_ENV_ROOT)/$(*) $(DEPLOY_ENV_ROOT)/$(*)
	$(SPACK_RUNTIME) -e $(DEPLOY_ENV_ROOT)/$(*) mirror add --unsigned dotbuild $(BUILDCACHE)
	$(SPACK_RUNTIME) -e $(DEPLOY_ENV_ROOT)/$(*) concretize
	$(SPACK_RUNTIME) -e $(DEPLOY_ENV_ROOT)/$(*) install --use-buildcache only
	$(SPACK_RUNTIME) env activate --sh $(DEPLOY_ENV_ROOT)/$(*) | $(PYTHON) $(_INTERNAL_MK_DIR)lib/make_load_sh.py > $(@).tmp
	mv $(@).tmp $(@)

# Remove a deployment's view and load.sh (installs stay until runtime-gc)
undeploy-%:
	rm -rf $(DOT_RUNTIME_ROOT)/$(*) $(DEPLOY_ENV_ROOT)/$(*)
	[ ! -f $(ACTIVE_FILE) ] || { grep -vx '$(*)' $(ACTIVE_FILE) > $(ACTIVE_FILE).tmp || true; mv $(ACTIVE_FILE).tmp $(ACTIVE_FILE); }

# Uninstall runtime packages no current deployment needs. Re-invokes make so
# DEPLOYED is computed fresh (e.g. after `make undeploy-x runtime-gc`).
# `spack gc -e` only keeps an env's *own* roots and ignores include_concrete,
# so the deploy envs alone would protect nothing. Pass every build env in each
# deployment's chain instead: their roots are exactly what the views hold.
runtime-gc:
	$(MAKE) --no-print-directory _runtime-gc

_runtime-gc:
	$(if $(DEPLOYED),,$(error nothing is deployed in $(DOT_RUNTIME_ROOT); use runtime-wipe instead))
	$(SPACK_RUNTIME) gc -y $(foreach E, $(sort $(call env-closure,$(DEPLOYED))), -e $(SPACK_ENV_ROOT)/$(E))

# ── Stow ─────────────────────────────────────────────────────────────
# stow comes from the deployed runtime (core)
stow: deploy
	for d in $(DEPLOY); do . $(DOT_RUNTIME_ROOT)/$$d/load.sh; done && stow --target $(HOME) stow-point

unstow:
	for d in $(DEPLOYED); do . $(DOT_RUNTIME_ROOT)/$$d/load.sh; done && stow --delete --target $(HOME) stow-point

# ── Cleanup ──────────────────────────────────────────────────────────
%-clean:
	rm -f $(SPACK_ENV_ROOT)/$(*)/spack.lock $(SPACK_ENV_ROOT)/$(*)/.cached

%-wipe:
	rm -rf $(SPACK_ENV_ROOT)/$(*)

# remove all build environments (keeps spack, its install tree and the buildcache)
wipe:
	rm -rf $(SPACK_ENV_ROOT)

# remove everything in the build root, including the spack clone and buildcache
build-wipe:
	rm -rf $(DOT_BUILD_ROOT)

# remove all deployments and the runtime install tree
runtime-wipe:
	rm -rf $(DOT_RUNTIME_ROOT) $(DEPLOY_ENV_ROOT)

# ── Generated include-concrete rules from <env>_PARENT ───────────────
$(foreach V,$(PARENT_VARS),$(eval $(call env-depends-on,$(V:%_PARENT=%),$($(V)))))
