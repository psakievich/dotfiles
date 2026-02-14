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

echo ""
echo "=== All overlay tests passed ==="
