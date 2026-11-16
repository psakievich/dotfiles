# Top-level environments to build. Parents (below) are built automatically.
ENVS = graphviz

# Include-concrete chain: <env>_PARENT = <parent env(s)>
# A child env reuses its parent's concretization, which keeps the combined
# runtime view free of conflicting builds of the same package.
editor_PARENT   = core
graphviz_PARENT = editor

# Optionally point to a different spack installation
# SPACK_ROOT = /some/local/path

# Deployed by `make all` / `make deploy`, in shell load order (later wins).
# Defaults to the leaves of ENVS; any built env can be deployed: make deploy-<env>
# DEPLOY = graphviz

# Machine-local additions (gitignored), e.g.
#   ENVS += work
#   work_PARENT = graphviz
#   DEPLOY = graphviz work
#   DOT_BUILD_ROOT = /scratch/$(USER)/dotbuild
-include local.mk

# Include the make file that builds everything else
include internal.mk
