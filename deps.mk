# deps.mk — Make-managed dependency clones (replaces git submodules)
#
# Each dependency is cloned via shallow git clone at a pinned version.
# URLs and versions can be overridden for corporate mirrors.

# ── Version pins ─────────────────────────────────────────────────────
SPACK_VERSION   ?= develop
TPM_VERSION     ?= master

# ── Repository URLs (override for corporate mirrors) ─────────────────
SPACK_URL       ?= https://github.com/spack/spack
TPM_URL         ?= https://github.com/tmux-plugins/tpm.git

# ── Clone paths ──────────────────────────────────────────────────────
SPACK_DIR       ?= spack
TPM_DIR         ?= .tmux/plugins/tpm

# ── Clone rules ──────────────────────────────────────────────────────
$(SPACK_DIR):
	git clone --depth 1 --branch $(SPACK_VERSION) $(SPACK_URL) $@
	$(@)/bin/spack repo set --scope site --destination '$$spack/etc/spack-packages' builtin
	$(@)/bin/spack bootstrap root '$$spack/etc/bootstrap'
	$(@)/bin/spack config --scope site add 'include:[$$spack/../configs]'

$(TPM_DIR):
	mkdir -p $(dir $@)
	git clone --depth 1 --branch $(TPM_VERSION) $(TPM_URL) $@

# ── Phony targets ────────────────────────────────────────────────────
.PHONY: deps update-deps

deps: $(SPACK_DIR) $(TPM_DIR)

update-deps:
	cd $(SPACK_DIR) && git fetch --depth 1 origin $(SPACK_VERSION) && git checkout FETCH_HEAD
	cd $(TPM_DIR) && git fetch --depth 1 origin $(TPM_VERSION) && git checkout FETCH_HEAD
