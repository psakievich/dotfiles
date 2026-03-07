_INTERNAL_MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
.DEFAULT_GOAL := all
include $(_INTERNAL_MK_DIR)deps.mk

.PHONY: all clean wipe

SPACK_ROOT ?= spack

SPACK := $(SPACK_ROOT)/bin/spack
ENV_PREFIX := $(SPACK_ROOT)/var/spack/environments
MANAGER_CONFIG := $(SPACK_ROOT)/etc/spack/config.yaml
SPACK_ENV_ROOT ?= $(SPACK_ROOT)/var/spack/environments
TEMPLATE_ROOT ?= spack_environments
ENV_OUT_DIR ?= env-src

MANAGED_ENVS ?= $(shell ls $(TEMPLATE_ROOT))
MANAGED_YAML := $(foreach ME, $(MANAGED_ENVS), $(SPACK_ENV_ROOT)/$(ME)/spack.yaml)
ENVS ?= MANAGED_ENVS
ENV_TARGETS ?= $(foreach E, $(ENVS), $(ENV_OUT_DIR)/$(E)_load.sh)

.PRECIOUS: $(SPACK_ENV_ROOT)/%/spack.yaml $(SPACK_ENV_ROOT)/%/spack.lock

.PHONY: all clean $(ENVS) stow

all: $(ENVS)
clean:
	$(info does nothing right now)

stow: | $(ENV_OUT_DIR)
	source $$(ls -tr $(ENV_OUT_DIR)/* | tail -1) && stow --target $(HOME) stow-point

$(ENVS): %: $(ENV_OUT_DIR)/%_load.sh
	$(info $(*) installed)

$(ENV_TARGETS): $(ENV_OUT_DIR)/%_load.sh: $(SPACK_ENV_ROOT)/%/spack.lock
	$(SPACK) -e $(*) install --reuse
	$(SPACK) -e $(*) env view enable
	$(SPACK) env activate --sh $(*) | grep -Ev "SPACK_ENV|alias" > $(ENV_OUT_DIR)/$(*)_load.sh

$(SPACK_ENV_ROOT)/%/spack.lock: $(SPACK_ENV_ROOT)/%/spack.yaml
	$(SPACK) -e $(*) concretize

$(SPACK_ENV_ROOT)/%/spack.yaml: $(TEMPLATE_ROOT)/%/spack.yaml
	[ ! -f $(@) ] || $(SPACK) env rm -y --force $(*)
	$(SPACK) env create $(*) $(<)

# Usage: $(eval $(call env-depends-on,<env>,<parent-env>))
# Generates a spack.yaml rule that uses --include-concrete to inherit
# concretization from a parent environment.
define env-depends-on
$(SPACK_ENV_ROOT)/$(1)/spack.yaml: $(2) $(TEMPLATE_ROOT)/$(1)/spack.yaml
	[ ! -f $$(@) ] || $$(SPACK) env rm -y --force $(1)
	$$(SPACK) env create --include-concrete $$(word 1, $$^) $(1) $$(word 2, $$^)
endef

$(ENV_OUT_DIR): | $(SPACK_DIR)
	mkdir -p $(ENV_OUT_DIR)

%-clean:
	rm $($(SPACK) location -e $(*))/spack.lock

%-wipe:
	$(SPACK) env rm -y $(*)

wipe:
	rm -rf $(ENV_PREFIX)

