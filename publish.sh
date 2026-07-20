#!/bin/bash

VERSION=$1
# Changelog URL varies per release (slug is not derivable from the version) and
# defaults to the changelog index. Override for a specific page, e.g.
# CHANGELOG_URL=https://docs.purchasely.com/changelog/60-... sh publish.sh 6.0.0
CHANGELOG_URL="${CHANGELOG_URL:-https://docs.purchasely.com/changelog}"

# Function to update changelog if version entry doesn't exist
update_changelog() {
    local changelog_file=$1

    # Check if this version already exists in the changelog
    if grep -q "^## ${VERSION}$" "$changelog_file"; then
        echo "Version ${VERSION} already exists in ${changelog_file}, skipping..."
    else
        echo "Adding version ${VERSION} to ${changelog_file}..."
        # Create temp file with new entry + existing content
        {
            echo "## ${VERSION}"
            echo "Full changelog available at ${CHANGELOG_URL}"
            echo ""
            cat "$changelog_file"
        } > "${changelog_file}.tmp"
        mv "${changelog_file}.tmp" "$changelog_file"
    fi
}

# Replace version number in yaml files
sed -i '' "s/^.*version:.*$/version: ${VERSION}/" purchasely/pubspec.yaml
sed -i '' "s/^.*version:.*$/version: ${VERSION}/" purchasely_google/pubspec.yaml
sed -i '' "s/^.*version:.*$/version: ${VERSION}/" purchasely_android_player/pubspec.yaml

# Replace version number in android plugin
sed -i '' "s/^.*Purchasely.sdkBridgeVersion.*$/        Purchasely.sdkBridgeVersion = \"${VERSION}\"/" purchasely/android/src/main/kotlin/io/purchasely/purchasely_flutter/PurchaselyFlutterPlugin.kt

# Replace version number in ios plugin
# v6 sets the bridge version via the builder chain `.sdkBridgeVersion("…")`
# (12-space indentation inside the Purchasely.apiKey(...) chain).
sed -i '' "s/^.*\.sdkBridgeVersion(.*$/            .sdkBridgeVersion(\"${VERSION}\")/" purchasely/ios/purchasely_flutter/Classes/SwiftPurchaselyFlutterPlugin.swift

# Update all CHANGELOG.md files
update_changelog "purchasely/CHANGELOG.md"
update_changelog "purchasely_google/CHANGELOG.md"
update_changelog "purchasely_android_player/CHANGELOG.md"

# Publish
if [[ $2 = true ]]
then
    cd purchasely && flutter pub publish
    cd ../purchasely_google && flutter pub publish
    cd ../purchasely_android_player && flutter pub publish
else
    cd purchasely && flutter pub publish --dry-run
    cd ../purchasely_google && flutter pub publish --dry-run
    cd ../purchasely_android_player && flutter pub publish --dry-run
fi
