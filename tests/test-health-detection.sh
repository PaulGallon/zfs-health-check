#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "${temp_dir}"' EXIT

cat >"${temp_dir}/zpool" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "list" && "$*" == *"-o name"* ]]; then
  echo tank
elif [[ "$1" == "list" && "$*" == *"-o health"* ]]; then
  echo "${TEST_POOL_HEALTH}"
elif [[ "$1" == "list" && "$*" == *"-o capacity"* ]]; then
  echo 42%
elif [[ "$1" == "status" ]]; then
  cat "${TEST_STATUS_FIXTURE}"
else
  echo "Unexpected zpool arguments: $*" >&2
  exit 2
fi
EOF
chmod +x "${temp_dir}/zpool"

cat >"${temp_dir}/notify" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"${TEST_NOTIFICATION_OUTPUT}"
EOF
chmod +x "${temp_dir}/notify"

run_case() {
  local fixture=$1
  local health=$2
  local expected=$3
  local output="${temp_dir}/${health}.out"

  TEST_POOL_HEALTH="${health}" \
  TEST_STATUS_FIXTURE="${repo_dir}/tests/fixtures/${fixture}" \
  TEST_NOTIFICATION_OUTPUT="${output}" \
  ZPOOL_COMMAND="${temp_dir}/zpool" \
  NOTIFY_SCRIPT="${temp_dir}/notify" \
    "${repo_dir}/zfs-health-check-and-notification.sh"

  grep -Fq "${expected}" "${output}"
}

run_case healthy-with-removal-history.txt ONLINE "No issues found for this pool."
run_case degraded.txt DEGRADED "There are issues detected for this pool."

echo "Health detection tests passed."
