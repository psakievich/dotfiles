# An example of including a machine specific environment as precursor to the builtin ones
# First define the name of the environment you intend to pre-include and the other envs
# You wish to include
ENVS = base core editor

# Optionally point to a different spack installation
# SPACK_ROOT = /some/local/path

# Include the make file that builds everything else
include dotenvs.mk

# Define dependency rules for the other environments relative to the machine specific case
core: base
editor: core base
