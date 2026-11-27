#!/bin/bash
# Test env.sh loading and the `hermetic` shell function against a fake env
# file. Does not require spack.

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
unset DOTLOCAL DOT_ENV   # defaults: $HOME/.dotlocal (HOME is faked below), $DOTFILES/env.sh

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; echo "$OUT"; exit 1; }

# ── Fake env.sh: a tool on PATH plus some build variables ────────────
mkdir -p "$T/home" "$T/tools/bin"
printf '#!/bin/sh\necho hi\n' > "$T/tools/bin/faketool"
chmod +x "$T/tools/bin/faketool"
cat > "$T/env.sh" <<ENV
export PATH=$T/tools/bin"\${PATH:+:\$PATH}"
export CMAKE_PREFIX_PATH=$T/tools"\${CMAKE_PREFIX_PATH:+:\$CMAKE_PREFIX_PATH}"
export TOOLS_VAR=1
ENV
echo 'export DOTLOCAL_MARK=from-dotlocal' > "$T/home/.dotlocal"

PROBE='echo "PATH=$PATH"
echo "TOOLS=${TOOLS_VAR-unset}"
echo "CMAKE=${CMAKE_PREFIX_PATH-unset}"
echo "MODE=${DOT_HERMETIC-unset}"
echo "CFG=${MYCONFIGINSTALLED-unset}"
echo "KEEP=${FOO_KEEP-unset}"
echo "SH=${DOT_HERMETIC_SHELL-unset}"
echo "MARK=${DOTLOCAL_MARK-unset}"
command -v faketool >/dev/null && echo "faketool=yes" || echo "faketool=no"'

# run <shell> <commands>: load the profile in <shell> with DOT_ENV pointing at
# the fake env.sh (override by setting DOT_ENV), then run <commands>
run() {
  local sh=$1; shift
  HOME="$T/home" DOT_ENV="${DOT_ENV-$T/env.sh}" FOO_KEEP=kept PROBE="$PROBE" \
    "$sh" -c 'source "$0/stow-point/.profile" 2>&1; '"$*" "$DOTFILES"
}
has() { echo "$OUT" | grep -q -- "$1"; }

SHELLS=(bash)
command -v zsh >/dev/null && SHELLS+=(zsh)

for SH in "${SHELLS[@]}"; do
  echo "=== env.sh + hermetic ($SH) ==="

  # ── env.sh loading ──
  OUT=$(run "$SH" 'sh -c "$PROBE"')
  has "TOOLS=1" && has "faketool=yes" && has "PATH=$T/tools/bin:" \
    && pass "profile sources DOT_ENV" || fail "DOT_ENV not sourced"

  OUT=$(DOT_ENV="$T/missing.sh" run "$SH" 'sh -c "$PROBE"; echo "rc=$?"')
  has "TOOLS=unset" && has "CFG=1" && has "rc=0" \
    && pass "missing env file is skipped quietly" || fail "missing env file"

  OUT=$(run "$SH" 'sh -c "$PROBE"')
  has "MARK=from-dotlocal" && pass "profile sources ~/.dotlocal" || fail "~/.dotlocal not sourced"

  # ── hermetic ──
  OUT=$(run "$SH" 'hermetic -- sh -c "$PROBE"')
  has "TOOLS=unset" && has "CMAKE=unset" && has "faketool=no" \
    && has "MODE=config" && has "CFG=1" && has "MARK=from-dotlocal" && ! has "$T/tools" \
    && pass "default: dotfiles config, no env.sh" || fail "default mode"

  OUT=$(run "$SH" 'hermetic --env -- sh -c "$PROBE"')
  has "TOOLS=1" && has "faketool=yes" && has "MODE=env" && has "CFG=1" \
    && pass "--env: dotfiles config + env.sh" || fail "--env mode"

  OUT=$(run "$SH" 'hermetic --bare -- sh -c "$PROBE"')
  has "TOOLS=unset" && has "faketool=no" && has "CFG=unset" && has "MODE=bare" \
    && pass "--bare: no dotfiles, no env.sh" || fail "--bare mode"

  OUT=$(run "$SH" 'hermetic -- sh -c "$PROBE"; DOT_HERMETIC_KEEP=FOO_KEEP hermetic -- sh -c "$PROBE"')
  [ "$(echo "$OUT" | grep -c "KEEP=unset")" = 1 ] && has "KEEP=kept" \
    && pass "DOT_HERMETIC_KEEP passes extra variables through" || fail "DOT_HERMETIC_KEEP"

  OUT=$(run "$SH" 'hermetic -- sh -c "$PROBE"')
  has "SH=$SH" && pass "child shell defaults to the parent shell ($SH)" || fail "default child shell"

  for CHILD in "${SHELLS[@]}"; do
    OUT=$(run "$SH" "hermetic --shell $CHILD --env -- sh -c \"\$PROBE\"")
    has "SH=$CHILD" && has "CFG=1" && has "TOOLS=1" \
      && pass "--shell $CHILD --env: dotfiles config + env.sh" || fail "--shell $CHILD"
  done

  OUT=$(run "$SH" 'hermetic --shell fish -- true 2>&1; echo "rc=$?"')
  has "unsupported shell 'fish'" && has "rc=2" && pass "unsupported --shell is rejected" || fail "unsupported shell"
done

echo ""
echo "=== All hermetic tests passed ==="
