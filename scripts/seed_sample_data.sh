#!/usr/bin/env bash
# Seed Firestore with sample Community Quran Todo data
# Usage:
#   ./scripts/seed_sample_data.sh <project-id> <seed-token> [target] [region] [function-name]
#
# Example (deployed project):
#   ./scripts/seed_sample_data.sh my-firebase-app my-secret-token
#
# Example (emulator):
#   ./scripts/seed_sample_data.sh my-firebase-app my-secret-token local

set -euo pipefail

# If user runs via bash and files are not executable, make them executable for future convenience.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd || echo ".")"
for s in "${SCRIPTS_DIR}/check_function_exists.sh" "${SCRIPTS_DIR}/seed_sample_data.sh" "${SCRIPTS_DIR}/fix_permissions.sh"; do
  if [[ -e "$s" && ! -x "$s" ]]; then
    chmod +x "$s" 2>/dev/null && echo "Made executable: ${s}" || true
  fi
done

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <project-id> <seed-token> [target] [region] [function-name]" >&2
  echo "  target: 'local' to call the local emulator (default: remote)"
  echo "  region: cloud functions region (default: us-central1)"
  echo "  function-name: deployed function name (default: seedSampleData)"
  exit 1
fi

PROJECT_ID="$1"
SEED_TOKEN="$2"
TARGET="${3:-remote}"        # local or remote
REGION="${4:-us-central1}"
FUNCTION_NAME="${5:-seedSampleData}"

if [[ "$TARGET" == "local" ]]; then
  # Emulator URL format: http://127.0.0.1:5001/<project-id>/<region>/<function>
  URL="http://127.0.0.1:5001/${PROJECT_ID}/${REGION}/${FUNCTION_NAME}"
else
  # Deployed functions URL (Gen 1): https://<region>-<project>.cloudfunctions.net/<function>
  URL="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}"
fi

echo "Sending seed request to ${URL}"
echo "Project: ${PROJECT_ID}, Region: ${REGION}, Function: ${FUNCTION_NAME}, Target: ${TARGET}"

# Perform request, capture headers and body for easier debugging.
TMP_BODY="$(mktemp)"
TMP_HEADERS="$(mktemp)"

HTTP_STATUS=$(curl -sS -D "${TMP_HEADERS}" -o "${TMP_BODY}" -w "%{http_code}" \
  -X POST \
  -H "x-seed-token: ${SEED_TOKEN}" \
  "${URL}" || true)

echo "HTTP status: ${HTTP_STATUS}"
echo "Response headers:"
cat "${TMP_HEADERS}" || true
echo
echo "Response body:"
cat "${TMP_BODY}" || true
echo

# cleanup both temp files
rm -f "${TMP_HEADERS}" "${TMP_BODY}"

if [[ "${HTTP_STATUS}" != "200" ]]; then
  echo "Seed request failed with status ${HTTP_STATUS}" >&2
  if [[ "${HTTP_STATUS}" == "404" ]]; then
    echo "404 indicates the function URL was not found."
    echo "Possible causes:"
    echo "  - The function is deployed under a different region."
    echo "  - The function name differs (e.g. seed_sample_data vs seedSampleData)."
    echo "  - The project id is incorrect."
    echo

    # Try a common alternate URL pattern (no region prefix)
    ALT_URL="https://${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}"
    echo "Trying alternate URL: ${ALT_URL}"
    ALT_BODY="$(mktemp)"
    ALT_HEADERS="$(mktemp)"
    ALT_STATUS=$(curl -sS -D "${ALT_HEADERS}" -o "${ALT_BODY}" -w "%{http_code}" \
      -X POST -H "x-seed-token: ${SEED_TOKEN}" "${ALT_URL}" || true)
    echo "Alternate HTTP status: ${ALT_STATUS}"
    echo "Alternate response headers:"
    cat "${ALT_HEADERS}" || true
    echo
    echo "Alternate response body:"
    cat "${ALT_BODY}" || true
    echo
    rm -f "${ALT_HEADERS}" "${ALT_BODY}"

    echo "Next diagnostics:"
    # If helper exists, run it to list functions and show https URLs
    if [[ -x "$(dirname "$0")/check_function_exists.sh" ]]; then
      echo "Running helper: ./scripts/check_function_exists.sh ${PROJECT_ID} ${REGION} ${FUNCTION_NAME}"
      "$(dirname "$0")/check_function_exists.sh" "${PROJECT_ID}" "${REGION}" "${FUNCTION_NAME}" || true
    elif command -v gcloud >/dev/null 2>&1; then
      echo "gcloud found — attempting to describe the function:"
      echo "  gcloud functions describe ${FUNCTION_NAME} --project ${PROJECT_ID} --region ${REGION} --format='value(httpsTrigger.url)'"
      gcloud functions describe "${FUNCTION_NAME}" --project "${PROJECT_ID}" --region "${REGION}" --format="value(httpsTrigger.url)" 2>/dev/null || \
      gcloud functions describe "${FUNCTION_NAME}" --project "${PROJECT_ID}" --format="value(httpsTrigger.url)" 2>/dev/null || true

      echo
      echo "Also listing functions in the project (name,region,httpsTrigger.url):"
      gcloud functions list --project "${PROJECT_ID}" --format="table(name,region,httpsTrigger.url)" 2>/dev/null || true
    else
      echo "No helper script or gcloud available."
      echo "Try listing functions in the GCP console:"
      echo "  https://console.cloud.google.com/functions?project=${PROJECT_ID}"
    fi

    echo
    echo "Attempting direct Firestore write as a fallback (requires gcloud and auth)."
    if command -v gcloud >/dev/null 2>&1; then
      ACCESS_TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token 2>/dev/null || true)"
      if [[ -z "${ACCESS_TOKEN}" ]]; then
        echo "Unable to obtain an access token from gcloud. Ensure you're authenticated:"
        echo "  gcloud auth login"
        echo "or"
        echo "  gcloud auth application-default login"
      else
        FIRESTORE_BASE="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents"
        echo "Using Firestore REST endpoint: ${FIRESTORE_BASE}"
        # prepare sample documents
        TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        declare -a SAMPLE_DOCS
        SAMPLE_DOCS+=('{"fields":{"title":{"stringValue":"Learn Surah Al-Fatiha"},"description":{"stringValue":"Read and memorize the first surah"},"owner":{"stringValue":"community"},"completed":{"booleanValue":false},"createdAt":{"timestampValue":"'"${TIMESTAMP}"'"}}}')
        SAMPLE_DOCS+=('{"fields":{"title":{"stringValue":"Recite Surah Yaseen"},"description":{"stringValue":"Daily recitation for blessings"},"owner":{"stringValue":"community"},"completed":{"booleanValue":false},"createdAt":{"timestampValue":"'"${TIMESTAMP}"'"}}}')
        SAMPLE_DOCS+=('{"fields":{"title":{"stringValue":"Memorize 5 verses"},"description":{"stringValue":"Focus on meaning and pronunciation"},"owner":{"stringValue":"community"},"completed":{"booleanValue":false},"createdAt":{"timestampValue":"'"${TIMESTAMP}"'"}}}')

        echo "Inserting ${#SAMPLE_DOCS[@]} sample documents into collection 'community_todos'..."
        for doc_json in "${SAMPLE_DOCS[@]}"; do
          RESP_FILE="$(mktemp)"
          HTTP_CODE=$(curl -sS -o "${RESP_FILE}" -w "%{http_code}" \
            -X POST \
            -H "Authorization: Bearer ${ACCESS_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${doc_json}" \
            "${FIRESTORE_BASE}/community_todos" || true)

          echo "Firestore insert HTTP status: ${HTTP_CODE}"
          if [[ "${HTTP_CODE}" == "200" || "${HTTP_CODE}" == "201" ]]; then
            echo "Inserted document. Response:"
            cat "${RESP_FILE}"
            echo
          else
            echo "Failed to insert document. Response:"
            cat "${RESP_FILE}" || true
            echo
          fi
          rm -f "${RESP_FILE}"
        done

        echo "Direct Firestore fallback completed. Verify documents in Firestore console or with gcloud:"
        echo "  gcloud firestore documents list --project ${PROJECT_ID} 2>/dev/null || use the Console: https://console.firebase.google.com/project/${PROJECT_ID}/firestore/data"
      fi
    else
      echo "gcloud not available — cannot perform direct Firestore fallback."
    fi

    echo
    echo "If you still see 404 for the function and prefer function-based seeding, confirm the deployed function name/region and re-run:"
    echo "  ./scripts/seed_sample_data.sh <PROJECT_ID> <SEED_TOKEN> remote <REGION> <FUNCTION_NAME>"
  fi
  exit 1
fi

echo "Seed data inserted successfully."





