# Flutter Swift Package Manager Design

**Scope:** Flutter SDK only; branch targets `feat/sdk-v6-migration`.

The Flutter plugin will expose a `Package.swift` that builds the existing Swift bridge against the Purchasely iOS Swift package while preserving Flutter's generated package integration. The package will include only sources and resources required by the bridge, declare the correct framework linkage, and include privacy metadata only when it is packaged by this target rather than already supplied by the native SDK.

A separate macOS CI lane will build the example through SwiftPM. The existing CocoaPods install and iOS build lane stays mandatory to protect current consumers.
