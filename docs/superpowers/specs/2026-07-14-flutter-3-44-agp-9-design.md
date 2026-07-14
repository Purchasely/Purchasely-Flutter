# Flutter 3.44 and AGP 9 Compatibility Design

**Scope:** Flutter SDK only; branch targets `feat/sdk-v6-migration`.

CI will add an explicit compatibility lane for Flutter 3.44, AGP 9, the matching modern Gradle/Kotlin toolchain, and the recommended JDK. It will run Dart checks and build release APK/AAB artifacts for the main example plus Android builds for the supported Google and player extensions. Existing lanes remain in place until the new lane is proven.

Only build-script and source adaptations required by these builds will be made. The change does not alter Purchasely runtime behavior or broaden the native SDK dependency upgrade scope.
