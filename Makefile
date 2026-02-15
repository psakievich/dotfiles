# An example of including a machine specific environment as precursor to the builtin ones
# First define the name of the environment you intend to pre-include and the other envs
# You wish to include
# EXTERNAL_ENV := base
ENVS = core editor $(EXTERNAL_ENV)

# Optionally point to a different spack installation
# SPACK_ROOT = /some/local/path

# Include the make file that builds everything else
include internal.mk

# Define dependency rules for the other environments relative to the machine specific case
core: $(EXTERNAL_ENV)
editor: $(EXTERNAL_ENV) core
graphviz: $(EXTERNAL_ENV) core editor
