#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/test.sh [unit|ui|all] [extra xcodebuild args...]

Builds the Lumen scheme for testing and runs tests on an iOS Simulator.
Build output goes to build/DerivedData so it never touches Xcode's own DerivedData.

  unit   LumenTests only (default)
  ui     LumenUITests only
  all    every test target

Pass a single test with: scripts/test.sh unit -only-testing:LumenTests/TopicVoteTests
Override the simulator with: LUMEN_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
Pick an Xcode with: DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
EOF
}

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

suite="${1:-unit}"
[[ $# -gt 0 ]] && shift

case "$suite" in
  unit) target_filter=(-only-testing:LumenTests) ;;
  ui) target_filter=(-only-testing:LumenUITests) ;;
  all) target_filter=() ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac

if [[ " $* " == *" -only-testing:"* ]]; then
  target_filter=()
fi

destination="${LUMEN_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2}"
derived_data="build/DerivedData"
result_bundle="build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult"

formatter=(cat)
if command -v xcbeautify >/dev/null 2>&1; then
  formatter=(xcbeautify --quieter)
fi

set +e
xcodebuild \
  -project Lumen.xcodeproj \
  -scheme Lumen \
  -destination "$destination" \
  -configuration Debug \
  -derivedDataPath "$derived_data" \
  -resultBundlePath "$result_bundle" \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO \
  ${target_filter[@]+"${target_filter[@]}"} \
  "$@" \
  test 2>&1 | "${formatter[@]}"
status=$?
set -e

if [[ -d "$result_bundle" ]]; then
  summary="$(xcrun xcresulttool get test-results summary --path "$result_bundle")"
  for field in result passedTests failedTests skippedTests; do
    printf '%s=%s ' "$field" "$(plutil -extract "$field" raw -o - - <<<"$summary")"
  done
  echo
  echo "Result bundle: $result_bundle"
fi
exit "$status"
