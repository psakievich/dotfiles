# Dotfiles: configuration and scripts only.
#
# Tools (nvim, tmux, stow, ...) come from whatever the gitignored env.sh sets
# up; the shell sources it if present. tools/ builds a Spack deployment and
# can link env.sh to it: tools/install.sh $PWD/env.sh
#
#   make deps     clone tpm
#   make stow     link stow-point/ (i.e. ~/.profile) into $HOME
#   make unstow   remove those links
DOTFILES_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))/

TPM_VERSION ?= master
TPM_URL     ?= https://github.com/tmux-plugins/tpm.git
TPM_DIR     ?= $(DOTFILES_DIR).tmux/plugins/tpm
STOW        ?= stow
DOT_ENV     ?= $(DOTFILES_DIR)env.sh

# gitignored, worktree-local overrides
-include $(DOTFILES_DIR)local.mk

.PHONY: all deps update-deps stow unstow

all: deps

print-%:
	@echo $($(*))

deps: $(TPM_DIR)

$(TPM_DIR):
	mkdir -p $(dir $@)
	git clone --depth 1 --branch $(TPM_VERSION) $(TPM_URL) $@

update-deps:
	cd $(TPM_DIR) && git fetch --depth 1 origin $(TPM_VERSION) && git checkout FETCH_HEAD

# stow may itself come from env.sh
stow:
	[ ! -f '$(DOT_ENV)' ] || . '$(DOT_ENV)'; $(STOW) --dir $(DOTFILES_DIR) --target $(HOME) stow-point

unstow:
	[ ! -f '$(DOT_ENV)' ] || . '$(DOT_ENV)'; $(STOW) --dir $(DOTFILES_DIR) --target $(HOME) --delete stow-point
