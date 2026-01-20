
.PHONY: all clean wipe

SPACK_ROOT ?= spack
SPACK := $(SPACK_ROOT)/bin/spack
ENV_PREFIX := $(SPACK_ROOT)/var/spack/environments MANAGER_CONFIG := $(SPACK_ROOT)/etc/spack/config.yaml

ENVS := core editor graphviz

.PRECIOUS: $(ENV_PREFIX)/%/spack.yaml $(ENV_PREFIX)/%/spack.lock

all: $(ENVS)

$(ENVS): %: $(ENV_PREFIX)/%/spack.lock
	$(SPACK) -e $(*) install

$(ENV_PREFIX)/%/spack.lock: $(ENV_PREFIX)/%/spack.yaml
	$(SPACK) -e $(*) concretize

$(ENV_PREFIX)/%/spack.yaml: spack_environments/%/spack.yaml $(MANAGER_CONFIG)
	$(SPACK) manager create-env --name $(*) --yaml $(<) 
	$(SPACK) -e $(*) buildcache keys --install --trust

$(MANAGER_CONFIG): spack-manager/spack-manager.yaml
	$(SPACK) config --scope spack add "config:extensions:[$(PWD)/spack-manager]"
	$(SPACK) manager add dot-manager

clean:
	rm  *.mk

wipe:
	rm -rf $(ENV_PREFIX) *.mk

