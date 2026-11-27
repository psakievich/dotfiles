#!/bin/bash
# Check the tools Makefile's build -> buildcache -> deploy plan with `make -n`
# and a mock spack, and exercise `make link` for real. Does not need spack.

set -euo pipefail

TOOLS="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
unset DOT_BUILD_ROOT DOT_RUNTIME_ROOT SPACK_ROOT BUILDCACHE ENV_TEMPLATE

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; echo "$OUT"; exit 1; }
has() { echo "$OUT" | grep -qF -- "$1"; }

MOCK="$T/mock-spack"
mkdir -p "$MOCK/bin"
printf '#!/bin/sh\necho "mock-spack $*"\n' > "$MOCK/bin/spack"
chmod +x "$MOCK/bin/spack"

B="$T/scratch" R="$T/runtime"
mk() { make --no-print-directory -C "$TOOLS" DOT_BUILD_ROOT="$B" DOT_RUNTIME_ROOT="$R" "$@" 2>&1; }

echo "=== tools Makefile ==="

OUT=$(mk -n all SPACK_ROOT="$MOCK") || fail "make -n all failed"
has "$MOCK/bin/spack -C $TOOLS/configs/common -C $TOOLS/configs/build env create -d $B/env $TOOLS/spack.yaml" \
  && pass "build env created from tools/spack.yaml under DOT_BUILD_ROOT" || fail "build env"
has "-e $B/env concretize" && has "-e $B/env install" \
  && has "buildcache push --unsigned --update-index $B/buildcache" \
  && pass "concretize, install, push to DOT_BUILD_ROOT/buildcache" || fail "build stage"
has "configs/runtime env create -d --with-view $R/view --include-concrete $B/env $B/deploy" \
  && has "mirror add --unsigned dotbuild $B/buildcache" \
  && has "install --use-buildcache only" && has "> $R/load.sh.tmp" \
  && pass "deploy installs from the buildcache only into DOT_RUNTIME_ROOT" || fail "deploy stage"

touch "$T/other.yaml"
OUT=$(mk -n build SPACK_ROOT="$MOCK" ENV_TEMPLATE="$T/other.yaml" BUILDCACHE="$T/bc") || true
has "env create -d $B/env $T/other.yaml" && has "--update-index $T/bc" \
  && pass "ENV_TEMPLATE and BUILDCACHE can be overridden" || fail "overrides"

OUT=$(SPACK_ROOT=/from/setup-env mk print-SPACK_ROOT)
[ "$OUT" = "$B/spack" ] && pass "exported SPACK_ROOT is ignored" || fail "exported SPACK_ROOT"

# Spack unsets *_ROOT variables in build processes, so config scopes must not use them
OUT=$(grep -rnE --include="*.yaml" '\$\{?[A-Za-z_]*_ROOT\b' "$TOOLS/configs" || true)
[ -z "$OUT" ] && pass "config scopes avoid *_ROOT variables" || fail "config uses a *_ROOT variable"
OUT=$(mk print-DOTSPACK_BUILD; mk print-DOTSPACK_RUNTIME)
[ "$OUT" = "$B"$'\n'"$R" ] && pass "DOTSPACK_BUILD/RUNTIME follow the roots" || fail "DOTSPACK_*"

OUT=$(mk -n deps)
has "git clone --depth 1 --branch develop https://github.com/spack/spack $B/spack" \
  && pass "deps clones spack into DOT_BUILD_ROOT" || fail "deps"

OUT=$(mk gc SPACK_ROOT="$MOCK"; echo "rc=$?") || true
has "nothing is deployed" && pass "gc refuses when nothing is deployed" || fail "gc guard"

OUT=$(mk link LINK="$T/env.sh") && [ "$(readlink "$T/env.sh")" = "$R/load.sh" ] \
  && pass "link symlinks LINK to load.sh" || fail "link"
OUT=$(mk link LINK="$T/env.sh" DOT_RUNTIME_ROOT="$T/rt2") && [ "$(readlink "$T/env.sh")" = "$T/rt2/load.sh" ] \
  && pass "link replaces an existing symlink" || fail "link replace"
echo mine > "$T/own.sh"
OUT=$(mk link LINK="$T/own.sh"; echo "rc=$?") || true
has "not a symlink" && [ "$(cat "$T/own.sh")" = mine ] \
  && pass "link leaves a regular file alone" || fail "link regular file"

echo ""
echo "=== All tools Makefile tests passed ==="
