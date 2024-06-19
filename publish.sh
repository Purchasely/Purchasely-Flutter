#!/bin/bash

VERSION=$1

#replace version number in yaml file
sed -i '' "s/^.*version:.*$/version: ${VERSION}/" purchasely/pubspec.yaml
sed -i '' "s/^.*version:.*$/version: ${VERSION}/" purchasely_google/pubspec.yaml
sed -i '' "s/^.*purchasely_flutter:.*$/purchasely_flutter: ^${VERSION}/" purchasely_google/pubspec.yaml
sed -i '' "s/^.*version:.*$/version: ${VERSION}/" purchasely_android_player/pubspec.yaml

#replace version number in android plugin
sed -i '' "s/^.*Purchasely.sdkBridgeVersion.*$/\t  Purchasely.sdkBridgeVersion = \"${VERSION}\"/" purchasely/android/src/main/kotlin/io/purchasely/purchasely_flutter/PurchaselyFlutterPlugin.kt

#replace version number in ios plugin
sed -i '' "s/^.*Purchasely.setSdkBridgeVersion.*$/\t\tPurchasely.setSdkBridgeVersion(\"${VERSION}\")/" purchasely/ios/Classes/SwiftPurchaselyFlutterPlugin.swift

#publish
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
