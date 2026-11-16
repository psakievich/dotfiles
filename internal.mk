_INTERNAL_MK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/
.DEFAULT_GOAL := all

# ── Locations ────────────────────────────────────────────────────────
# Three roots, kept apart so HOME only ever holds config + runtime binaries:
#
#   $(DOTFILES)          this repo: configuration only
#   DOT_BUILD_ROOT       spack clone, build install tree, stage, caches,
#                        build environments, buildcache. Point it at scratch
#                        space when HOME is small; it is safe to delete.
#   DOT_RUNTIME_ROOT     runtime-only install tree (from the buildcache), a
#                        single view, and load.sh. This is what the shell uses.
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
RUNTIME_ENV    ?= $(DOT_BUILD_ROOT)/runtime-env
RUNTIME_LOAD   ?= $(DOT_RUNTIME_ROOT)/load.sh
CONFIG_ROOT    ?= $(_INTERNAL_MK_DIR)configs
TEMPLATE_ROOT  ?= spack_environments
PYTHON         ?= python3

# Include-concrete chain, declared as `<env>_PARENT = <parent env(s)>` before
# this file is included. Rules are generated at the bottom of this file.
PARENT_VARS := $(filter %_PARENT,$(.VARIABLES))
ALL_PARENTS := $(sort $(foreach V,$(PARENT_VARS),$($(V))))

# Environments whose specs end up in the runtime view. Included-concrete
# parents come along transitively, so only the leaves are needed.
RUNTIME_ENVS ?= $(filter-out $(ALL_PARENTS),$(ENVS))

# RUNTIME_ENVS plus all of their (transitive) parents
env-closure = $(foreach E,$(1),$(E) $(call env-closure,$($(E)_PARENT)))
RUNTIME_CLOSURE = $(sort $(call env-closure,$(RUNTIME_ENVS)))

# Spack config scopes reference these, and nothing should fall back to ~/.spack
export DOT_BUILD_ROOT DOT_RUNTIME_ROOT
export SPACK_DISABLE_LOCAL_CONFIG := 1
export SPACK_USER_CACHE_PATH := $(DOT_BUILD_ROOT)/user-cache

include $(_INTERNAL_MK_DIR)deps.mk

SPACK         := $(SPACK_ROOT)/bin/spack
SPACK_BUILD   := $(SPACK) -C $(CONFIG_ROOT)/common -C $(CONFIG_ROOT)/build
SPACK_RUNTIME := $(SPACK) -C $(CONFIG_ROOT)/common -C $(CONFIG_ROOT)/runtime

BUILD_SENTINELS := $(foreach E, $(ENVS), $(SPACK_ENV_ROOT)/$(E)/.cached)

.PRECIOUS: $(SPACK_ENV_ROOT)/%/spack.yaml $(SPACK_ENV_ROOT)/%/spack.lock $(SPACK_ENV_ROOT)/%/.cached

.PHONY: all build runtime runtime-gc clean wipe build-wipe runtime-wipe stow unstow $(ENVS)

all: runtime
build: $(ENVS)
runtime: $(RUNTIME_LOAD)

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

# ── Runtime stage (HOME) ─────────────────────────────────────────────
# One environment that include-concretes the build envs, installs their
# link/run closure from the buildcache only (no build deps, no compiling),
# and keeps a single view under DOT_RUNTIME_ROOT. load.sh only references
# the view, so DOT_BUILD_ROOT can be wiped without breaking the shell.
$(RUNTIME_LOAD): $(foreach E, $(RUNTIME_ENVS), $(SPACK_ENV_ROOT)/$(E)/.cached)
	rm -rf $(RUNTIME_ENV)
	mkdir -p $(DOT_RUNTIME_ROOT)
	$(SPACK_RUNTIME) env create -d --with-view $(DOT_RUNTIME_ROOT)/view \
	  $(foreach E, $(RUNTIME_ENVS), --include-concrete $(SPACK_ENV_ROOT)/$(E)) $(RUNTIME_ENV)
	$(SPACK_RUNTIME) -e $(RUNTIME_ENV) mirror add --unsigned dotbuild $(BUILDCACHE)
	$(SPACK_RUNTIME) -e $(RUNTIME_ENV) concretize
	$(SPACK_RUNTIME) -e $(RUNTIME_ENV) install --use-buildcache only
	$(SPACK_RUNTIME) env activate --sh $(RUNTIME_ENV) | $(PYTHON) $(_INTERNAL_MK_DIR)lib/make_load_sh.py > $(@).tmp
	mv $(@).tmp $(@)

# Remove runtime installs no longer needed by the runtime env (e.g. after
# dropping a package from an env). Matters most where HOME space is tight.
# `spack gc -e` only keeps an env's *own* roots and ignores include_concrete,
# so the runtime env alone would protect nothing. Pass every build env in
# the chain instead: their roots are exactly what the runtime view holds.
runtime-gc:
	$(SPACK_RUNTIME) gc -y $(foreach E, $(RUNTIME_CLOSURE), -e $(SPACK_ENV_ROOT)/$(E))

# ── Stow ─────────────────────────────────────────────────────────────
stow: $(RUNTIME_LOAD)
	. $(RUNTIME_LOAD) && stow --target $(HOME) stow-point

unstow: $(RUNTIME_LOAD)
	. $(RUNTIME_LOAD) && stow --delete --target $(HOME) stow-point

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

# remove the installed runtime (the shell falls back to no spack tools)
runtime-wipe:
	rm -rf $(DOT_RUNTIME_ROOT) $(RUNTIME_ENV)

# ── Generated include-concrete rules from <env>_PARENT ───────────────
$(foreach V,$(PARENT_VARS),$(eval $(call env-depends-on,$(V:%_PARENT=%),$($(V)))))
