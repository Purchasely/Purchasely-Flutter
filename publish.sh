#!/bin/bash

VERSION=$1

#replace version number in yaml file
sed -i '' "s/^.*version:.*$/version: ${VERSION}/" pubspec.yaml

#replace version number in android plugin
sed -i '' "s/^.*Purchasely.sdkBridgeVersion.*$/\t  Purchasely.sdkBridgeVersion = \"${VERSION}\"/" android/src/main/kotlin/io/purchasely/purchasely_flutter/PurchaselyFlutterPlugin.kt

#replace version number in ios plugin
sed -i '' "s/^.*Purchasely.sdkBridgeVersion.*$/\tPurchasely.sdkBridgeVersion = \"${VERSION}\"/" ios/Classes/SwiftPurchaselyFlutterPlugin.swift

#publish
if [[ $2 = true ]]
then
    flutter pub publish
else
    flutter pub publish --dry-run
fi
