#!/bin/bash
# Test deployment loading and the `hermetic` shell function against a fake
# runtime with two deployments. Does not require spack.

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; echo "$OUT"; exit 1; }

# ── Fake runtime root: deployments alpha (active) and beta ───────────
RT="$T/rt"
mkdir -p "$T/home"
for d in alpha beta; do
  mkdir -p "$RT/$d/view/bin"
  printf '#!/bin/sh\necho %s\n' "$d" > "$RT/$d/view/bin/${d}tool"
  chmod +x "$RT/$d/view/bin/${d}tool"
  UP=$(echo "$d" | tr a-z A-Z)
  cat > "$RT/$d/load.sh" <<LOAD
export PATH=$RT/$d/view/bin"\${PATH:+:\$PATH}"
export CMAKE_PREFIX_PATH=$RT/$d/view"\${CMAKE_PREFIX_PATH:+:\$CMAKE_PREFIX_PATH}"
export ${UP}_VAR=1
LOAD
done
echo alpha > "$RT/active"

PROBE='echo "PATH=$PATH"
echo "ALPHA=${ALPHA_VAR-unset} BETA=${BETA_VAR-unset}"
echo "CMAKE=${CMAKE_PREFIX_PATH-unset}"
echo "MODE=${DOT_HERMETIC-unset}"
echo "CFG=${MYCONFIGINSTALLED-unset}"
echo "KEEP=${FOO_KEEP-unset}"
echo "SH=${DOT_HERMETIC_SHELL-unset}"
for t in alphatool betatool; do command -v $t >/dev/null && echo "$t=yes" || echo "$t=no"; done'

# run <shell> <commands>: load the profile with the fake runtime in <shell>,
# then run <commands> (which may use $PROBE)
run() {
  local sh=$1; shift
  HOME="$T/home" DOT_RUNTIME_ROOT="$RT" FOO_KEEP=kept PROBE="$PROBE" \
    "$sh" -c 'source "$0/stow-point/.profile" 2>&1; '"$*" "$DOTFILES"
}
has() { echo "$OUT" | grep -q -- "$1"; }

SHELLS=(bash)
command -v zsh >/dev/null && SHELLS+=(zsh)

for SH in "${SHELLS[@]}"; do
  echo "=== deployments + hermetic ($SH) ==="

  # ── deployment loading ──
  OUT=$(run "$SH" 'sh -c "$PROBE"')
  has "ALPHA=1 BETA=unset" && has "alphatool=yes" && has "betatool=no" \
    && pass "shell loads the deployments listed in active" || fail "active deployments"

  OUT=$(DOT_DEPLOYMENTS="alpha beta" run "$SH" 'sh -c "$PROBE"')
  has "ALPHA=1 BETA=1" && has "PATH=$RT/beta/view/bin:$RT/alpha/view/bin:" \
    && pass "DOT_DEPLOYMENTS overrides active; later entries take precedence" || fail "DOT_DEPLOYMENTS order"

  OUT=$(DOT_DEPLOYMENTS= run "$SH" 'sh -c "$PROBE"')
  has "ALPHA=unset BETA=unset" && pass "empty DOT_DEPLOYMENTS loads nothing" || fail "empty DOT_DEPLOYMENTS"

  OUT=$(DOT_DEPLOYMENTS=gamma run "$SH" 'true')
  has "deployment 'gamma' not found" && pass "missing deployment warns" || fail "missing deployment warning"

  OUT=$(run "$SH" 'dot-deployments')
  has "^\* alpha" && has "^  beta" && pass "dot-deployments marks loaded deployments" || fail "dot-deployments"

  # ── hermetic ──
  OUT=$(run "$SH" 'hermetic -- sh -c "$PROBE"')
  has "ALPHA=unset BETA=unset" && has "CMAKE=unset" && has "alphatool=no" \
    && has "MODE=config" && has "CFG=1" && ! has "$RT" \
    && pass "default: dotfiles config loaded, no deployments" || fail "default mode"

  OUT=$(run "$SH" 'hermetic --deploy beta -- sh -c "$PROBE"')
  has "ALPHA=unset BETA=1" && has "betatool=yes" && has "alphatool=no" && has "CFG=1" \
    && pass "--deploy loads only the named deployment" || fail "--deploy"

  OUT=$(run "$SH" 'hermetic --deploy alpha,beta -- sh -c "$PROBE"')
  has "ALPHA=1 BETA=1" && pass "--deploy accepts a comma list" || fail "--deploy list"

  OUT=$(run "$SH" 'hermetic --tools -- sh -c "$PROBE"')
  has "ALPHA=unset BETA=unset" && has "CMAKE=unset" && has "alphatool=yes" \
    && has "betatool=no" && has "MODE=tools" \
    && pass "--tools: this shell's deployment bin/ only, no variables" || fail "--tools mode"

  OUT=$(run "$SH" 'hermetic --bare -- sh -c "$PROBE"')
  has "ALPHA=unset" && has "alphatool=no" && has "CFG=unset" && has "MODE=bare" \
    && pass "--bare: no dotfiles, no deployments" || fail "--bare mode"

  OUT=$(run "$SH" 'hermetic --bare --deploy alpha -- true 2>&1; echo "rc=$?"')
  has "drop --bare" && has "rc=2" && pass "--bare with --deploy is rejected" || fail "--bare --deploy"

  OUT=$(run "$SH" 'hermetic -- sh -c "$PROBE"; DOT_HERMETIC_KEEP=FOO_KEEP hermetic -- sh -c "$PROBE"')
  [ "$(echo "$OUT" | grep -c "KEEP=unset")" = 1 ] && has "KEEP=kept" \
    && pass "DOT_HERMETIC_KEEP passes extra variables through" || fail "DOT_HERMETIC_KEEP"

  OUT=$(run "$SH" 'hermetic -- sh -c "$PROBE"')
  has "SH=$SH" && pass "child shell defaults to the parent shell ($SH)" || fail "default child shell"

  for CHILD in "${SHELLS[@]}"; do
    OUT=$(run "$SH" "hermetic --shell $CHILD --deploy beta -- sh -c \"\$PROBE\"")
    has "SH=$CHILD" && has "CFG=1" && has "ALPHA=unset BETA=1" \
      && pass "--shell $CHILD: dotfiles config + requested deployment" || fail "--shell $CHILD"
  done

  OUT=$(run "$SH" 'hermetic --shell fish -- true 2>&1; echo "rc=$?"')
  has "unsupported shell 'fish'" && has "rc=2" && pass "unsupported --shell is rejected" || fail "unsupported shell"
done

echo ""
echo "=== All hermetic tests passed ==="
