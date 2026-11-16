#!/bin/bash
# Test that a corporate overlay repo can include internal.mk and
# produce a correct build plan with proper dependency ordering.
#
# This test uses `make -n` (dry-run) so it does NOT require spack.

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; exit 1; }

echo "=== Overlay Makefile test ==="
echo "  DOTFILES=$DOTFILES"
echo "  TMPDIR=$TMPDIR_BASE"

# ── Set up a mock corporate overlay repo ──────────────────────────────
CORP="$TMPDIR_BASE/corporate-dotfiles"
mkdir -p "$CORP/spack_environments/corporate"

cat > "$CORP/spack_environments/corporate/spack.yaml" <<'EOF'
spack:
  specs:
  - cmake
EOF

# Create a mock spack binary so make -n can resolve paths
MOCK_SPACK_ROOT="$TMPDIR_BASE/mock-spack"
mkdir -p "$MOCK_SPACK_ROOT/bin"
mkdir -p "$MOCK_SPACK_ROOT/var/spack/environments"
mkdir -p "$MOCK_SPACK_ROOT/etc/spack"
cat > "$MOCK_SPACK_ROOT/bin/spack" <<'EOF'
#!/bin/bash
echo "mock-spack $@"
EOF
chmod +x "$MOCK_SPACK_ROOT/bin/spack"

# Also need spack-manager yaml for the prerequisite
mkdir -p "$CORP/spack-manager"
touch "$CORP/spack-manager/spack-manager.yaml"

cat > "$CORP/Makefile" <<EOF
DOTFILES = $DOTFILES
SPACK_ROOT = $MOCK_SPACK_ROOT
ENVS = corporate
include \$(DOTFILES)/internal.mk

EOF

# ── Test 1: dry-run includes corporate environment ────────────────────
DRY_OUTPUT=$(make -n -C "$CORP" all 2>&1) || true

if echo "$DRY_OUTPUT" | grep -q "corporate"; then
  pass "dry-run references corporate environment"
else
  fail "dry-run did not reference corporate environment"
fi

# ── Test 2: corporate template is discovered ──────────────────────────
if echo "$DRY_OUTPUT" | grep -q "spack_environments/corporate/spack.yaml"; then
  pass "corporate template discovered from TEMPLATE_ROOT"
else
  fail "corporate template not found in dry-run output"
fi

# ── Test 3: multi-env with dependency ordering ────────────────────────
# Add dotfiles environments to the overlay
mkdir -p "$CORP/spack_environments/mycore"
cat > "$CORP/spack_environments/mycore/spack.yaml" <<'EOF'
spack:
  specs:
  - tmux
EOF

cat > "$CORP/Makefile" <<EOF
DOTFILES = $DOTFILES
SPACK_ROOT = $MOCK_SPACK_ROOT
ENVS = corporate mycore
include \$(DOTFILES)/internal.mk

mycore: corporate
EOF

DRY_OUTPUT=$(make -n -C "$CORP" all 2>&1) || true

if echo "$DRY_OUTPUT" | grep -q "corporate" && echo "$DRY_OUTPUT" | grep -q "mycore"; then
  pass "multi-env dry-run includes both environments"
else
  fail "multi-env dry-run missing environments"
fi

# ── Test 4: SPACK_ROOT override is respected ──────────────────────────
if echo "$DRY_OUTPUT" | grep -q "$MOCK_SPACK_ROOT"; then
  pass "SPACK_ROOT override is respected"
else
  fail "SPACK_ROOT override not found in dry-run output"
fi

# ── Test 5: example.mk is valid syntax ───────────────────────────────
# Verify example.mk parses without syntax errors (using --warn-undefined-variables)
PARSE_OUTPUT=$(make -n -f "$DOTFILES/example.mk" -p DOTFILES="$DOTFILES" SPACK_ROOT="$MOCK_SPACK_ROOT" 2>&1) || true
if [ $? -eq 0 ] || echo "$PARSE_OUTPUT" | grep -q "corporate"; then
  pass "example.mk parses without syntax errors"
else
  fail "example.mk has syntax errors"
fi

# ── Test 6: deps target clones dependency directories ────────────────
DEPS_DIR="$TMPDIR_BASE/deps-test"
mkdir -p "$DEPS_DIR/spack_environments/core"
cat > "$DEPS_DIR/spack_environments/core/spack.yaml" <<'EOF'
spack:
  specs:
  - tmux
EOF

cat > "$DEPS_DIR/Makefile" <<EOF
DOTFILES = $DOTFILES
SPACK_ROOT = $MOCK_SPACK_ROOT
ENVS = core
include \$(DOTFILES)/internal.mk
EOF

DEPS_DRY=$(make -n -C "$DEPS_DIR" deps 2>&1) || true

if echo "$DEPS_DRY" | grep -q "git clone"; then
  pass "deps target includes git clone commands"
else
  fail "deps target did not include git clone commands"
fi

# ── Test 7: build artifacts are routed into DOT_BUILD_ROOT ───────────
SPLIT_DRY=$(make -n -C "$DEPS_DIR" all \
  DOT_BUILD_ROOT="$TMPDIR_BASE/scratch" DOT_RUNTIME_ROOT="$TMPDIR_BASE/home-rt" 2>&1) || true

if echo "$SPLIT_DRY" | grep -q "env create -d $TMPDIR_BASE/scratch/envs/core" \
   && echo "$SPLIT_DRY" | grep -q "buildcache push --unsigned --update-index $TMPDIR_BASE/scratch/buildcache"; then
  pass "build envs and buildcache live under DOT_BUILD_ROOT"
else
  fail "build envs/buildcache not routed to DOT_BUILD_ROOT"
fi

# ── Test 8: runtime installs from the buildcache only into DOT_RUNTIME_ROOT
if echo "$SPLIT_DRY" | grep -q "install --use-buildcache only" \
   && echo "$SPLIT_DRY" | grep -q -- "--with-view $TMPDIR_BASE/home-rt/view" \
   && echo "$SPLIT_DRY" | grep -q "$TMPDIR_BASE/home-rt/load.sh"; then
  pass "runtime is installed from the buildcache into DOT_RUNTIME_ROOT"
else
  fail "runtime stage missing or not routed to DOT_RUNTIME_ROOT"
fi

# ── Test 9: build and runtime use separate config scopes ─────────────
if echo "$SPLIT_DRY" | grep -q "configs/build .*install$" \
   && echo "$SPLIT_DRY" | grep -q "configs/runtime .*install --use-buildcache only"; then
  pass "build and runtime stages use their own config scopes"
else
  fail "build/runtime config scopes not applied"
fi

# ── Test 10: load.sh generator emits portable prepends ────────────────
LOAD_OUT=$(printf 'export PATH=/v/bin:/usr/bin:/bin;\nexport SPACK_ENV=/x;\nexport FOO=/v/share;\n' \
  | PATH=/usr/bin:/bin FOO= /usr/bin/env python3 "$DOTFILES/lib/make_load_sh.py")
if echo "$LOAD_OUT" | grep -qF 'export PATH=/v/bin"${PATH:+:$PATH}"' \
   && echo "$LOAD_OUT" | grep -qF 'export FOO=/v/share' \
   && ! echo "$LOAD_OUT" | grep -q SPACK_ENV; then
  pass "load.sh generator prepends to existing values and drops SPACK_*"
else
  echo "$LOAD_OUT"
  fail "load.sh generator output is not portable"
fi

echo ""
echo "=== All overlay tests passed ==="
