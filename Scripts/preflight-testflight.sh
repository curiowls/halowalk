#!/usr/bin/env bash
# Preflight checks before uploading a HaloWalk TestFlight build.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${HALOWALK_TEAM_ID:-7JA4MHTFTW}"
CONTAINER_ID="${HALOWALK_CLOUDKIT_CONTAINER:-iCloud.com.halowalk.guardian}"
REQUIRED_FIELDS=("appleUserId" "locationSharingEnabled")

echo "HaloWalk TestFlight preflight"
echo "CloudKit container: ${CONTAINER_ID}"
echo "Team: ${TEAM_ID}"
echo ""

if [[ -f build/TestFlight/ExportOptions.plist ]]; then
  ENVIRONMENT=$(/usr/libexec/PlistBuddy -c "Print :iCloudContainerEnvironment" build/TestFlight/ExportOptions.plist 2>/dev/null || true)
  if [[ -n "${ENVIRONMENT}" && "${ENVIRONMENT}" != "Production" ]]; then
    echo "ERROR: build/TestFlight/ExportOptions.plist is not set to Production CloudKit."
    echo "Found iCloudContainerEnvironment=${ENVIRONMENT}"
    exit 1
  fi
fi

if [[ "${HALOWALK_CLOUDKIT_SCHEMA_DEPLOYED:-}" == "1" ]]; then
  echo "CloudKit schema confirmation supplied by HALOWALK_CLOUDKIT_SCHEMA_DEPLOYED=1."
  exit 0
fi

if command -v xcrun >/dev/null 2>&1; then
  TMP_SCHEMA="$(mktemp -t halowalk-production-schema.XXXXXX)"
  trap 'rm -f "${TMP_SCHEMA}"' EXIT

  echo "Checking Production CloudKit schema with cktool..."
  if [[ -n "${CKTOOL_TOKEN:-}" ]]; then
    EXPORT_RESULT=0
    xcrun cktool export-schema \
      --token "${CKTOOL_TOKEN}" \
      --team-id "${TEAM_ID}" \
      --container-id "${CONTAINER_ID}" \
      --environment production \
      --output-file "${TMP_SCHEMA}" >/dev/null 2>&1 || EXPORT_RESULT=$?
  else
    EXPORT_RESULT=0
    xcrun cktool export-schema \
      --team-id "${TEAM_ID}" \
      --container-id "${CONTAINER_ID}" \
      --environment production \
      --output-file "${TMP_SCHEMA}" >/dev/null 2>&1 || EXPORT_RESULT=$?
  fi
  if [[ "${EXPORT_RESULT}" -eq 0 ]]; then
    for FIELD in "${REQUIRED_FIELDS[@]}"; do
      if ! rg -q "${FIELD}" "${TMP_SCHEMA}"; then
        echo "ERROR: Production CloudKit schema is missing Member.${FIELD}."
        echo "Deploy Development schema changes to Production in CloudKit Console before uploading."
        exit 1
      fi
    done

    echo "Production CloudKit schema contains required Build C Member fields."
    exit 0
  fi

  echo "cktool could not verify Production schema automatically."
fi

cat <<'MESSAGE'
Manual CloudKit schema confirmation required.

Before uploading a TestFlight build, verify in CloudKit Console:
  Container: iCloud.com.halowalk.guardian
  Production schema includes Member.appleUserId
  Production schema includes Member.locationSharingEnabled

If the fields are only in Development, use Deploy Schema Changes first.
This prevents the invite failure:
  Cannot create or modify field 'locationSharingEnabled' in record 'Member' in production schema

To continue, type DEPLOYED.
Set HALOWALK_CLOUDKIT_SCHEMA_DEPLOYED=1 to bypass this prompt after verifying.
MESSAGE

if [[ -t 0 ]]; then
  read -r CONFIRMATION
else
  echo "ERROR: non-interactive shell and no CKTOOL_TOKEN/HALOWALK_CLOUDKIT_SCHEMA_DEPLOYED confirmation provided."
  exit 1
fi

if [[ "${CONFIRMATION}" != "DEPLOYED" ]]; then
  echo "ERROR: CloudKit schema deployment was not confirmed."
  exit 1
fi

echo "CloudKit schema deployment confirmed."
