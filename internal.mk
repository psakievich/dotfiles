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

MANAGED_ENVS ?= $(shell ls $(TEMPLATE_ROOT))
MANAGED_YAML := $(foreach ME, $(MANAGED_ENVS), $(SPACK_ENV_ROOT)/$(ME)/spack.yaml)
ENVS ?= MANAGED_ENVS
ENV_TARGETS = $(foreach E, $(ENVS), $(SPACK_ENV_ROOT)/$(E)/last_build)

.PRECIOUS: $(SPACK_ENV_ROOT)/%/spack.yaml $(SPACK_ENV_ROOT)/%/spack.lock

.PHONY: all clean $(ENVS)

all: $(ENVS)
clean:
	$(info does nothing right now)

stow: core
	$(SPACK) -e $(<) build-env stow -- stow --target $(HOME) .

$(ENVS): %: $(SPACK_ENV_ROOT)/%/last_build
	$(info $(*) installed)

$(ENV_TARGETS): $(SPACK_ENV_ROOT)/%/last_build: $(SPACK_ENV_ROOT)/%/spack.lock
	$(SPACK) -e $(*) install --reuse
	$(SPACK) -e $(*) env view enable $(PWD)/spack-views/$(*)-bin
	touch $(SPACK_ENV_ROOT)/$(*)/last_build

$(SPACK_ENV_ROOT)/%/spack.lock: $(SPACK_ENV_ROOT)/%/spack.yaml
	$(SPACK) -e $(*) concretize

$(MANAGED_YAML): $(SPACK_ENV_ROOT)/%/spack.yaml: $(TEMPLATE_ROOT)/%/spack.yaml | $(MANAGER_CONFIG)
	$(SPACK) env rm -y $(*)
	$(SPACK) manager create-env --name $(*) --yaml $(<) 

$(MANAGER_CONFIG): | $(SPACK_DIR) $(SM_DIR)
	$(SPACK) config --scope spack add "config:extensions:[$(PWD)/spack-manager]"
	$(SPACK) manager add dot-manager

%-clean:
	rm $($(SPACK) location -e $(*))/spack.lock

%-wipe:
	$(SPACK) env rm -y $(*)

wipe:
	rm -rf $(ENV_PREFIX)

