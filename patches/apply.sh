#!/usr/bin/env bash
# Apply local patches to submodules. Run after `git submodule update --init`.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KSU_DIR="$REPO_ROOT/KernelSU-Next"
PATCH_DIR="$REPO_ROOT/patches/ksunext"

if [[ ! -d "$KSU_DIR" ]]; then
	echo "error: KernelSU-Next/ missing — run 'git submodule update --init' first" >&2
	exit 1
fi

if [[ ! -d "$PATCH_DIR" ]]; then
	echo "no patches/ksunext dir; nothing to apply"
	exit 0
fi

cd "$KSU_DIR"

# Detect already-applied state by checking for one of the patched symbols.
# Safer than blindly re-applying (would fail with "Reversed (or previously applied) patch detected").
if grep -q "track_throne(false);" kernel/supercalls.c; then
	echo "KernelSU-Next patches already applied; skipping"
	exit 0
fi

for p in "$PATCH_DIR"/*.patch; do
	echo "applying $(basename "$p")"
	git apply --whitespace=nowarn "$p"
done

echo "done. KernelSU-Next/ now has local patches applied."
echo "Note: 'git status' inside KernelSU-Next/ will show modified files — that's expected."
