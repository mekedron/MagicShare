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
echo "Pre-commit will auto-format staged Dart files in app/ and common/."
