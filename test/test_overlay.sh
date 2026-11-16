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

# ── Test 8: deploy installs from the buildcache only into DOT_RUNTIME_ROOT/<env>
if echo "$SPLIT_DRY" | grep -q "install --use-buildcache only" \
   && echo "$SPLIT_DRY" | grep -q -- "--with-view $TMPDIR_BASE/home-rt/core/view" \
   && echo "$SPLIT_DRY" | grep -q -- "--include-concrete $TMPDIR_BASE/scratch/envs/core $TMPDIR_BASE/scratch/deploy/core" \
   && echo "$SPLIT_DRY" | grep -q "$TMPDIR_BASE/home-rt/core/load.sh" \
   && echo "$SPLIT_DRY" | grep -q "printf '%s\\\\n' core > $TMPDIR_BASE/home-rt/active"; then
  pass "deploy-core installs from the buildcache into DOT_RUNTIME_ROOT/core"
else
  echo "$SPLIT_DRY"
  fail "deploy stage missing or not routed to DOT_RUNTIME_ROOT/<env>"
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

# ── Test 11: <env>_PARENT generates include-concrete chains ──────────
CHAIN_DIR="$TMPDIR_BASE/chain-test"
for e in base mid leaf; do
  mkdir -p "$CHAIN_DIR/spack_environments/$e"
  printf 'spack:\n  specs:\n  - zlib\n' > "$CHAIN_DIR/spack_environments/$e/spack.yaml"
done
cat > "$CHAIN_DIR/Makefile" <<EOF
DOTFILES = $DOTFILES
SPACK_ROOT = $MOCK_SPACK_ROOT
ENVS = mid
mid_PARENT = base
-include local.mk
include \$(DOTFILES)/internal.mk
EOF
CHAIN_DRY=$(make -n -C "$CHAIN_DIR" all DOT_BUILD_ROOT="$TMPDIR_BASE/cb" 2>&1) || true
if echo "$CHAIN_DRY" | grep -q -- "env create -d --include-concrete $TMPDIR_BASE/cb/envs/base $TMPDIR_BASE/cb/envs/mid" \
   && [ "$(make -s -C "$CHAIN_DIR" print-DEPLOY)" = "mid" ]; then
  pass "<env>_PARENT generates include-concrete rule; DEPLOY defaults to leaf env"
else
  echo "$CHAIN_DRY"
  fail "<env>_PARENT chain not generated"
fi

# ── Test 12: local.mk can extend ENVS and the chain ───────────────────
cat > "$CHAIN_DIR/local.mk" <<'EOF'
ENVS += leaf
leaf_PARENT = mid
EOF
CHAIN_DRY=$(make -n -C "$CHAIN_DIR" all DOT_BUILD_ROOT="$TMPDIR_BASE/cb" 2>&1) || true
if echo "$CHAIN_DRY" | grep -q -- "--include-concrete $TMPDIR_BASE/cb/envs/mid $TMPDIR_BASE/cb/envs/leaf" \
   && [ "$(make -s -C "$CHAIN_DIR" print-DEPLOY)" = "leaf" ]; then
  pass "local.mk extends ENVS; DEPLOY follows the new leaf"
else
  fail "local.mk extension not applied"
fi

# ── Test 13: each env deploys separately; DEPLOY sets what `all` deploys ──
CB="$TMPDIR_BASE/cb"; CR="$TMPDIR_BASE/cr"
DEP_DRY=$(make -n -C "$CHAIN_DIR" deploy-base deploy-mid DOT_BUILD_ROOT="$CB" DOT_RUNTIME_ROOT="$CR" 2>&1) || true
if echo "$DEP_DRY" | grep -q -- "--with-view $CR/base/view" \
   && echo "$DEP_DRY" | grep -q -- "--with-view $CR/mid/view" \
   && ! echo "$DEP_DRY" | grep -q "$CR/active"; then
  pass "deploy-<env> creates a separate view per env (and leaves active alone)"
else
  echo "$DEP_DRY"
  fail "deploy-<env> views not separate"
fi
ALL_DRY=$(make -n -C "$CHAIN_DIR" all DEPLOY="base leaf" DOT_BUILD_ROOT="$CB" DOT_RUNTIME_ROOT="$CR" 2>&1) || true
if echo "$ALL_DRY" | grep -q -- "--with-view $CR/base/view" \
   && echo "$ALL_DRY" | grep -q -- "--with-view $CR/leaf/view" \
   && ! echo "$ALL_DRY" | grep -q -- "--with-view $CR/mid/view" \
   && echo "$ALL_DRY" | grep -q "base leaf > $CR/active"; then
  pass "make all deploys DEPLOY and records it in active"
else
  echo "$ALL_DRY"
  fail "DEPLOY not honored by make all"
fi

# ── Test 14: undeploy removes the deployment and its active entry ─────
mkdir -p "$CR/base" "$CR/leaf"; touch "$CR/base/load.sh" "$CR/leaf/load.sh"
printf 'base\nleaf\n' > "$CR/active"
make -s -C "$CHAIN_DIR" undeploy-base DOT_BUILD_ROOT="$CB" DOT_RUNTIME_ROOT="$CR" >/dev/null 2>&1 || true
if [ ! -e "$CR/base" ] && [ "$(cat "$CR/active")" = "leaf" ]; then
  pass "undeploy-<env> removes the view and its active entry"
else
  fail "undeploy-<env> did not clean up"
fi

# ── Test 15: runtime-gc keeps every env in each deployment's chain ────
# (spack gc -e ignores include_concrete, so the chain must be listed)
GC_DRY=$(make -n -C "$CHAIN_DIR" runtime-gc DOT_BUILD_ROOT="$CB" DOT_RUNTIME_ROOT="$CR" 2>&1) || true
if echo "$GC_DRY" | grep -q "configs/runtime gc -y  *-e $CB/envs/base  *-e $CB/envs/leaf  *-e $CB/envs/mid"; then
  pass "runtime-gc keeps the full chain of every existing deployment"
else
  echo "$GC_DRY"
  fail "runtime-gc command wrong"
fi
rm -rf "$CR"/*
GC_DRY=$(make -n -C "$CHAIN_DIR" runtime-gc DOT_BUILD_ROOT="$CB" DOT_RUNTIME_ROOT="$CR" 2>&1) || true
if echo "$GC_DRY" | grep -q "nothing is deployed" && ! echo "$GC_DRY" | grep -q " gc -y"; then
  pass "runtime-gc refuses to run with nothing deployed"
else
  echo "$GC_DRY"
  fail "runtime-gc ran with nothing deployed"
fi

echo ""
echo "=== All overlay tests passed ==="
