#!/usr/bin/env bash
# If you see "Permission denied" run with:
#   bash ./scripts/check_function_exists.sh <project-id> [region] [function-name]
set -euo pipefail

# Attempt to make helper scripts executable when invoked via bash so future ./script runs work.
# This is safe: if chmod fails (lack of permissions) we silently continue and the user can run via bash.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd || echo ".")"
for s in "${SCRIPTS_DIR}/check_function_exists.sh" "${SCRIPTS_DIR}/seed_sample_data.sh" "${SCRIPTS_DIR}/fix_permissions.sh"; do
  if [[ -e "$s" && ! -x "$s" ]]; then
    chmod +x "$s" 2>/dev/null && echo "Made executable: ${s}" || true
  fi
done

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <project-id> [region] [function-name]" >&2
  exit 1
fi

PROJECT_ID="$1"
REGION="${2:-us-central1}"
FUNCTION_NAME="${3:-seedSampleData}"

if command -v gcloud >/dev/null 2>&1; then
  echo "Listing functions for project: ${PROJECT_ID} (region hint: ${REGION})"
  echo
  if ! gcloud functions list --project "${PROJECT_ID}" --region "${REGION}" --format="table(name,region,entryPoint,httpsTrigger.url)" 2>/dev/null; then
    echo "Region-specific listing failed or returned nothing; falling back to project-wide listing..."
    gcloud functions list --project "${PROJECT_ID}" --format="table(name,region,entryPoint,httpsTrigger.url)" 2>/dev/null || true
  fi

  echo
  echo "Attempting to describe '${FUNCTION_NAME}' to show its HTTPS URL (if present)..."
  gcloud functions describe "${FUNCTION_NAME}" --project "${PROJECT_ID}" --region "${REGION}" --format="value(httpsTrigger.url)" 2>/dev/null || \
  gcloud functions describe "${FUNCTION_NAME}" --project "${PROJECT_ID}" --format="value(httpsTrigger.url)" 2>/dev/null || true

  echo
  echo "If the function isn't listed or has no httpsTrigger.url, check the Firebase/GCP console:"
  echo "  https://console.cloud.google.com/functions?project=${PROJECT_ID}"
  exit 0
else
  echo "gcloud not installed. Open the Cloud Functions console to inspect functions:"
  echo "  https://console.cloud.google.com/functions?project=${PROJECT_ID}"
  exit 2
fi
