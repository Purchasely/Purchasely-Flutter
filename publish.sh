#!/bin/bash

VERSION=$1

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
            echo "Full changelog available at https://docs.purchasely.com/changelog/56"
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
sed -i '' "s/^.*Purchasely.sdkBridgeVersion.*$/\t  Purchasely.sdkBridgeVersion = \"${VERSION}\"/" purchasely/android/src/main/kotlin/io/purchasely/purchasely_flutter/PurchaselyFlutterPlugin.kt

# Replace version number in ios plugin
sed -i '' "s/^.*Purchasely.setSdkBridgeVersion.*$/\t\tPurchasely.setSdkBridgeVersion(\"${VERSION}\")/" purchasely/ios/Classes/SwiftPurchaselyFlutterPlugin.swift

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
