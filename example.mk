# Example: Corporate/site-specific overlay Makefile
#
# This file is a template for creating a PRIVATE repository that layers
# additional spack environments on top of the public dotfiles.
#
# Usage:
#   1. Create a private repo (e.g. ~/corporate-dotfiles/)
#   2. Copy this file into it as "Makefile"
#   3. Create spack_environments/<env>/spack.yaml for each corporate env
#   4. Set DOTFILES to point at your public dotfiles clone
#   5. Run: make all
#
# Directory layout:
#   corporate-dotfiles/
#   ├── Makefile                          (this file)
#   └── spack_environments/
#       └── corporate/
#           └── spack.yaml               (corporate packages)

# ── Path to the public dotfiles repo ──────────────────────────────────
DOTFILES ?= $(HOME)/dotfiles

# ── Environments to build ─────────────────────────────────────────────
# List corporate environments first, then the dotfiles ones you want.
ENVS = corporate core editor

# ── Optionally override spack installation ────────────────────────────
# Uncomment to use a site-wide spack instead of the bundled spack clone.
# SPACK_ROOT = /opt/spack

# ── Pull in the build rules from the public dotfiles ──────────────────
include $(DOTFILES)/internal.mk

# ── Dependency ordering ───────────────────────────────────────────────
# Corporate environment builds first; dotfiles environments depend on it.
core: corporate
editor: corporate core
