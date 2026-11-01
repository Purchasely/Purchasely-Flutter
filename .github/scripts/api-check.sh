#!/bin/bash
# Compare the public API of the three published packages with their last release on pub.dev.
# Fails on a breaking change that the version in pubspec.yaml does not allow.
# Reports every other change without failing. Run it from any folder of the repo.
set -uo pipefail

APITOOL_VERSION=0.23.2

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel) || exit 1
dart pub global activate dart_apitool "$APITOOL_VERSION" >/dev/null || exit 1
export PATH="$PATH:${PUB_CACHE:-$HOME/.pub-cache}/bin"

reports=$(mktemp -d)
trap 'rm -rf "$reports"' EXIT
summary=${GITHUB_STEP_SUMMARY:-/dev/stdout}
status=0

for dir in purchasely purchasely_google purchasely_android_player; do
  name=$(grep '^name:' "$root/$dir/pubspec.yaml" | awk '{print $2}')
  version=$(grep '^version:' "$root/$dir/pubspec.yaml" | awk '{print $2}')
  # pub.dev "latest" is the highest stable release: the local version when it is published,
  # else the release before it (a release candidate is not on pub.dev yet).
  if ! baseline=$(curl -fsS "https://pub.dev/api/packages/$name" | jq -er '.latest.version'); then
    echo "::error::Cannot read the last release of $name from pub.dev"
    status=1
    continue
  fi
  echo "== $name $version (local) vs $baseline (pub.dev)"

  dart-apitool diff \
    --old "pub://$name/$baseline" \
    --new "$root/$dir" \
    --version-check-mode onlyBreakingChanges \
    --report-format markdown \
    --report-file-path "$reports/$name.md"
  code=$?
  if [ "$code" -ne 0 ]; then
    echo "::error::$name: dart-apitool exit $code. A breaking change that version $version does not allow, or a tool error. Read the log."
    status=1
  fi
  { echo "## $name $version vs $baseline (exit $code)"; cat "$reports/$name.md" 2>/dev/null; echo; } >>"$summary"
done

exit "$status"
