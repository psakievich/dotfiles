# An example of including a machine specific environment as precursor to the builtin ones
# First define the name of the environment you intend to pre-include and the other envs
# You wish to include
# EXTERNAL_ENV := base
ENVS = editor

# Optionally point to a different spack installation
# SPACK_ROOT = /some/local/path

# Include the make file that builds everything else
include internal.mk

# Define dependency rules for the other environments relative to the machine specific case
core: $(SPACK_ENV_ROOT)/core/spack.lock

$(SPACK_ENV_ROOT)/editor/spack.yaml: core $(TEMPLATE_ROOT)/editor/spack.yaml
	[ ! -f $(@) ] || $(SPACK) env rm -y --force editor
	$(SPACK) env create --include-concrete $(word 1, $^) editor $(word 2, $^)

graphviz: $(EXTERNAL_ENV) core editor
