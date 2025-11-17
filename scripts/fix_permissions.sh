#!/usr/bin/env bash
# Make project helper scripts executable.
# Run with: bash ./scripts/fix_permissions.sh
set -euo pipefail

SCRIPTS=(
  "./scripts/check_function_exists.sh"
  "./scripts/seed_sample_data.sh"
  "./scripts/fix_permissions.sh"
)

for s in "${SCRIPTS[@]}"; do
  if [[ -e "${s}" ]]; then
    chmod +x "${s}" && echo "Made executable: ${s}" || echo "Failed to chmod: ${s} (run: bash ${s} or chmod +x ${s})"
  else
    echo "Not found: ${s}"
  fi
done
