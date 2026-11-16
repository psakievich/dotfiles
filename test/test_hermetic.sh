#!/bin/bash
# Test the `hermetic` shell function against a fake runtime view.
# Does not require spack.

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; echo "$OUT"; exit 1; }

# ── Fake runtime root ────────────────────────────────────────────────
RT="$T/rt"
mkdir -p "$RT/view/bin" "$T/home"
printf '#!/bin/sh\necho fake\n' > "$RT/view/bin/faketool"
chmod +x "$RT/view/bin/faketool"
cat > "$RT/load.sh" <<LOAD
export PATH=$RT/view/bin"\${PATH:+:\$PATH}"
export CMAKE_PREFIX_PATH=$RT/view"\${CMAKE_PREFIX_PATH:+:\$CMAKE_PREFIX_PATH}"
export LEAKY_VIEW_VAR=1
LOAD

PROBE='echo "PATH=$PATH"
echo "LEAK=${LEAKY_VIEW_VAR-unset}"
echo "CMAKE=${CMAKE_PREFIX_PATH-unset}"
echo "MODE=${DOT_HERMETIC-unset}"
echo "CFG=${MYCONFIGINSTALLED-unset}"
echo "KEEP=${FOO_KEEP-unset}"
command -v faketool >/dev/null && echo TOOL=yes || echo TOOL=no'

# run <shell> <hermetic args...>: load the profile with the fake runtime in
# <shell>, then run the probe through `hermetic`
run() {
  local sh=$1; shift
  HOME="$T/home" DOT_RUNTIME_ROOT="$RT" FOO_KEEP=kept PROBE="$PROBE" \
    "$sh" -c 'source "$0/stow-point/.profile" >/dev/null 2>&1; '"$*" "$DOTFILES"
}

SHELLS=(bash)
command -v zsh >/dev/null && SHELLS+=(zsh)

for SH in "${SHELLS[@]}"; do
  echo "=== hermetic ($SH) ==="

  OUT=$(run "$SH" 'sh -c "$PROBE"')
  echo "$OUT" | grep -q "LEAK=1" && echo "$OUT" | grep -q "TOOL=yes" \
    && pass "normal shell loads the view" || fail "normal shell did not load the view"

  OUT=$(run "$SH" 'hermetic -- sh -c "$PROBE"')
  echo "$OUT" | grep -q "LEAK=unset" && echo "$OUT" | grep -q "CMAKE=unset" \
    && echo "$OUT" | grep -q "TOOL=no" && echo "$OUT" | grep -q "MODE=config" \
    && echo "$OUT" | grep -q "CFG=1" && ! echo "$OUT" | grep -q "$RT" \
    && pass "default: dotfiles config loaded, no view" || fail "default mode"

  OUT=$(run "$SH" 'hermetic --tools -- sh -c "$PROBE"')
  echo "$OUT" | grep -q "LEAK=unset" && echo "$OUT" | grep -q "CMAKE=unset" \
    && echo "$OUT" | grep -q "TOOL=yes" && echo "$OUT" | grep -q "MODE=tools" \
    && pass "--tools: view/bin on PATH, no view variables" || fail "--tools mode"

  OUT=$(run "$SH" 'hermetic --bare -- sh -c "$PROBE"')
  echo "$OUT" | grep -q "LEAK=unset" && echo "$OUT" | grep -q "TOOL=no" \
    && echo "$OUT" | grep -q "CFG=unset" && echo "$OUT" | grep -q "MODE=bare" \
    && pass "--bare: no dotfiles, no view" || fail "--bare mode"

  OUT=$(run "$SH" 'hermetic -- sh -c "$PROBE"; DOT_HERMETIC_KEEP=FOO_KEEP hermetic -- sh -c "$PROBE"')
  [ "$(echo "$OUT" | grep -c "KEEP=unset")" = 1 ] && echo "$OUT" | grep -q "KEEP=kept" \
    && pass "DOT_HERMETIC_KEEP passes extra variables through" || fail "DOT_HERMETIC_KEEP"
done

echo ""
echo "=== All hermetic tests passed ==="
