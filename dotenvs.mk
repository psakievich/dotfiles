SPACK_ROOT ?= spack
SPACK := $(SPACK_ROOT)/bin/spack
SPACK_ENV_ROOT ?= $(SPACK_ROOT)/var/spack/environments
TEMPLATE_ROOT ?= spack_environments

MUTATE_ENVS ?= $(shell ls $(TEMPLATE_ROOT))
ENVS ?= $(MUTATE_ENVS)

.PRECIOUS: $(SPACK_ENV_ROOT)/%/spack.yaml $(SPACK_ENV_ROOT)/%/spack.lock

$(ENVS): %: $(SPACK_ENV_ROOT)/%/spack.lock
	$(SPACK) -e $(*) install

$(SPACK_ENV_ROOT)/%/spack.lock: $(SPACK_ENV_ROOT)/%/spack.yaml #%-mutate
	$(SPACK) -e $(*) concretize --force

# roots needs to exist to call this, so does spack.yaml
# but if roots doesn't exist we don't want to call it
# define CREATE_MUTATE_RULE
# if $(wildcard $(TEMPLATE_ROOT)/$1)
# $1-mutate: $(TEMPLATE_ROOT)/$1/roots $(SPACK_ENV_ROOT)/$1/spack.yaml
# 	$(SPACK) -e $1 add $(shell cat $(<))
# 	touch $1-mutate
# else
# $1-mutate: $(SPACK_ENV_ROOT)/$(1)/spack.yaml
# 	touch $1-mutate
# endif
# endef

# $(foreach e, $(ENV), $(eval $(call CREATE_MUTATE_RULE, $(e)))) 

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
