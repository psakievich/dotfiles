SPACK_ROOT ?= spack
SPACK := $(SPACK_ROOT)/bin/spack
SPACK_ENV_ROOT ?= $(SPACK_ROOT)/var/spack/environments
TEMPLATE_ROOT ?= spack_environments

MUTATE_ENVS ?= $(shell ls $(TEMPLATE_ROOT))
ENVS ?= $(MUTATE_ENVS)

.PRECIOUS: $(SPACK_ENV_ROOT)/%/spack.yaml $(SPACK_ENV_ROOT)/%/spack.lock

define root-list-variables
	$1_ROOTS = $(TEMPLATE_ROOT)/$1/roots
endef

$(foreach ME, $(MUTATE_ENVS), $(eval $(call root-list-variables,$(ME))))

ROOT_FILES := $(foreach ME, $(MUTATE_ENVS), $(TEMPLATE_ROOT)/$(ME)/roots)
LOCK_FILES := $(foreach ME, $(MUTATE_ENVS), $(SPACK_ENV_ROOT)/$(ME)/spack.lock)

$(ENVS): %: $(SPACK_ENV_ROOT)/%/spack.lock $(SPACK_ENV_ROOT)/%/spack.yaml
	$(SPACK) -e $(*) install

$(filter $(SPACK_ENV_ROOT)/%/spack.lock, $(LOCK_FILES)): $(SPACK_ENV_ROOT)/%/spack.lock: $(TEMPLATE_ROOT)/%/roots
	$(SPACK) -e $(*) concretize --force

$(filter $(TEMPLATE_ROOT)/%/roots, $(ROOT_FILES)): $(TEMPLATE_ROOT)/%/roots: $(SPACK_ENV_ROOT)/%/spack.yaml
	$(SPACK) -e $(*) add $(shell cat $(@))

# create an envionment
$(SPACK_ENV_ROOT)/%/spack.yaml:
	eval `$(SPACK) env activate --sh --create $(*)`
	$(SPACK) -e $(*) view enable spack-views/$(*)-bin

spack-views:
	mkdir -p spack-views

clean-%:
	rm $($(SPACK) location -e $(*))/spack.lock

wipe-%:
	$(SPACK) env rm -y $(*)
