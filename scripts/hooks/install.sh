#!/usr/bin/env bash
# Point this clone's git hooks at scripts/hooks/.
# Run once after cloning the repo:
#
#     ./scripts/hooks/install.sh
#
# To uninstall: `git config --unset core.hooksPath`.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

git config core.hooksPath scripts/hooks
chmod +x scripts/hooks/pre-commit

echo "Git hooks enabled (core.hooksPath = scripts/hooks)."
echo "Pre-commit will:"
echo "  1. auto-format staged Dart files in app/ and common/, and"
echo "  2. run flutter/dart analyze on those files; the commit fails on"
echo "     any finding (matches CI's flutter analyze step)."
echo
echo "Bypass with SKIP_DART_FORMAT_HOOK=1 / SKIP_DART_ANALYZE_HOOK=1 /"
echo "SKIP_DART_HOOKS=1 for one commit when needed."
