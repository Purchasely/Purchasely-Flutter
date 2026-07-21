# Rapport de migration Flutter → Purchasely SDK natif 6.0

> Session du 2026-06-15 sur la branche `feat/sdk-v6-migration`.
> Ce document récapitule **tout ce qui a été fait** pour finaliser la migration
> du plugin Flutter vers les SDK natifs Purchasely 6.0, et sert de source pour
> mettre à jour `../Documentation` (docs publiques) et `../purchasely-ai-skill`
> (références `flutter/`), comme cela a été fait pour Android et iOS.

---

## 1. Contexte et principe

Le plugin Flutter Purchasely est un **bridge Dart ↔ natif** (MethodChannel /
EventChannel) vers les SDK natifs iOS (`Purchasely`) et Android
(`io.purchasely:core`). Cette migration **adapte le bridge aux SDK natifs 6.0**.

Principe directeur (validé avec le demandeur) :

- **Pas de nommage « v6 » dans l'API Dart.** Les nouvelles méthodes **remplacent**
  l'existant. Quand il n'y a pas de nouvelle méthode native (ex. `setUserAttribute*`,
  `synchronize`), on **laisse en l'état**.
- Trois zones sont des breaking changes : **démarrage du SDK**, **affichage /
  preload / fermeture d'une présentation**, et **l'action interceptor**. Le reste
  de la surface `Purchasely.*` reste source-compatible. Les deeplinks prennent les
  noms v6 (`allowDeeplink`, `handleDeeplink`) avec alias dépréciés.

L'essentiel de la couche Dart, du bridge Android et du bridge iOS **existait déjà**
sur la branche au début de la session (le modèle mental « iOS pas commencé » était
obsolète — iOS était en réalité très avancé). Le travail de cette session a consisté
à : **vérifier la compilation contre les vrais SDK natifs v6**, **corriger les
divergences d'API**, **ajouter le callback à `synchronize`**, **compléter les tests**,
et **valider sur simulateurs**.

---

## 2. Changements effectués cette session

### 2.1 `synchronize()` — ajout du callback (Dart + Android + iOS)

Les SDK natifs 6.0 exposent désormais des callbacks succès/erreur sur
`synchronize()`. Le bridge a été câblé pour en profiter :

- **Dart** (`lib/purchasely_flutter.dart`) : `synchronize()` garde sa signature
  `Future<void>` mais **résout réellement à la fin de la synchronisation** et
  **lève une `PlatformException` en cas d'échec** (au lieu du fire-and-forget).
  Source-compatible pour le code qui faisait déjà `await`.
- **Android** (`PurchaselyFlutterPlugin.kt`) : `synchronize(result)` appelle
  `Purchasely.synchronize(onSuccess = { result.success(true) }, onError = { e -> result.error(...) })`
  (signature native `synchronize(onSuccess: (PLYPlan?) -> Unit, onError: (PLYError?) -> Unit)`).
  Avant, le bridge appelait `Purchasely.synchronize()` puis `result.success(true)`
  immédiatement (sans attendre).
- **iOS** (`SwiftPurchaselyFlutterPlugin.swift`) : les callbacks de
  `Purchasely.synchronize(success:failure:)` étaient **commentés** (la `Future`
  Dart ne se résolvait jamais → gel). Décommentés → `result(true)` / `result(error)`.

### 2.2 Corrections de compilation iOS (contre le SDK natif `develop` / 6.0.0-rc.2)

- `PLYPresentationBuilder.from(presentationId:)` **n'existe pas** en v6 →
  remplacé par `PLYPresentationBuilder.from(screenId:)`.
- `PLYPresentationOutcome(purchaseResult:plan:)` (init 2 args) **n'existe pas** →
  remplacé par l'init 0-arg `PLYPresentationOutcome()` (présent dans
  `SwiftPurchaselyFlutterPlugin.swift` et `NativeView.swift`).
- `Purchasely.subscriptionsController()` **supprimé** en v6 → `presentSubscriptions`
  a été **entièrement retiré** du SDK Flutter (alignement React Native). (Voir §2.5.)
- Transitions `drawer`/`popin` : passage de l'API dépréciée
  `.drawer(heightPercentage:dismissible:)` à `.drawer(height: .percentage(...), dismissible:)`
  (et `popin(width:nil, height:.percentage(...), ...)`).
- **Bonus** : iOS v6 expose maintenant `PLYPresentationOutcome.closeReason` (la doc
  disait le contraire). Le bridge le mappe désormais via `closeReason.rawDescription`
  (`button` / `back_system` / `programmatic`), au lieu de toujours envoyer `null`.

### 2.3 Corrections de compilation Android (contre `io.purchasely:core:6.0.0-rc.2`)

- Constructeur `PLYTransition` : l'ordre des paramètres a changé en v6
  (`type, width, height, heightPercentage, backgroundColors, dismissible`).
  L'appel positionnel du bridge provoquait un type-mismatch → réécrit en arguments
  nommés avec le modèle moderne `PLYTransitionDimension(PLYDimensionType.PERCENTAGE, ratio)`
  pour `height`.

### 2.4 Pin des versions natives → pré-release **`6.0.0-rc.2`** (publié, dépôts publics)

Les pins étaient sur `6.0.0` (artefact antérieur à la source vérifiée — il
manquait p.ex. `synchronize(onSuccess, onError)`). Version finale retenue :
**`6.0.0-rc.2` sur les DEUX plateformes**, qui est **réellement publiée** —
Android sur **Maven Central**, iOS sur le **CocoaPods trunk**. Conséquence :
le projet builde depuis les dépôts publics, **`mavenLocal()` retiré** (Android)
et **dev-pod retiré** (iOS) → le Podfile n'a plus de chemin absolu.

> Attention au token exact : c'est `6.0.0-rc.2` (**avec point**) partout. Le
> `6.0.0-rc1` (sans point) n'existe QUE dans un `~/.m2` local — il est 404 sur
> Maven Central comme sur CocoaPods.

| Fichier | Avant | Après |
|---|---|---|
| `purchasely/android/build.gradle` | `io.purchasely:core:6.0.0` | `io.purchasely:core:6.0.0-rc.2` |
| `purchasely_google/android/build.gradle` | `io.purchasely:google-play:6.0.0` | `…:6.0.0-rc.2` |
| `purchasely_android_player/android/build.gradle` | `io.purchasely:player:6.0.0` | `…:6.0.0-rc.2` |
| `purchasely/ios/purchasely_flutter.podspec` | `Purchasely '6.0.0'` | `Purchasely '6.0.0-rc.2'` |
| `purchasely/example/android/app/build.gradle` | `google-play:6.0.0`, `player:6.0.0` | `…:6.0.0-rc.2` |
| `purchasely/example/android/build.gradle` | `mavenLocal()` présent | retiré (Maven Central suffit) |
| `purchasely/example/ios/Podfile` | dev-pod `:path => '/Users/kevin/Purchasely/iOS'` | retiré (résout depuis le trunk) |

> Même chaîne `6.0.0-rc.2` (avec point) sur les deux plateformes ; publiée sur
> Maven Central (Android) et CocoaPods trunk (iOS). `mavenLocal()` et le dev-pod
> iOS ne sont plus nécessaires.

> ⚠️ **Piège Gradle (crash runtime trouvé par le test d'intégration).** L'`app/build.gradle`
> de l'exemple pinnait `google-play:6.0.0` / `player:6.0.0`, qui remontaient
> `core:6.0.0` transitivement. **Gradle classe `6.0.0` (release) au-dessus de
> `6.0.0-rc.2` (pré-release)** : le `core` était donc silencieusement remonté à
> `6.0.0` au runtime alors que le plugin compilait contre `6.0.0-rc.2` →
> `java.lang.NoSuchMethodError` sur le constructeur `PLYTransition` v6
> (signature `PLYTransitionDimension` absente du `6.0.0`). Corrigé en pinnant
> aussi l'exemple sur `6.0.0-rc.2`. **À retenir** : toutes les dépendances
> `io.purchasely:*` doivent pointer la MÊME version pré-release, sinon une seule
> référence `6.0.0` perdue casse tout le runtime.

### 2.5 `presentSubscriptions` (retiré) / `displaySubscriptionCancellationInstruction`

Les écrans natifs d'abonnements et de désabonnement ont été retirés des SDK 6.0
**sur les deux plateformes**. `presentSubscriptions` a donc été **entièrement
supprimé** du SDK Flutter (Dart + iOS + Android + tests + docs), pour s'aligner
sur le SDK React Native — **BREAKING CHANGE** sans remplacement : reconstruire son
propre écran via `userSubscriptions()` / `userSubscriptionsHistory()`.
`displaySubscriptionCancellationInstruction` est également supprimé du SDK Flutter v6.

### 2.6 Tests ajoutés / mis à jour

- **Dart** (`test/platform_channel_test.dart`) : 2 tests `synchronize` ajoutés —
  résolution effective (await + timeout) et propagation d'erreur (`PlatformException`).
- **Android** (`PurchaselyFlutterPluginTest.kt`) : test `synchronize` câblé bout en
  bout sans mock du SDK `@JvmStatic` (chemin « no store » → `onError` → `result.error`).
- **iOS** (`RunnerTests/SwiftPurchaselyFlutterPluginTests.swift`) : fichier **recréé**
  (il avait été supprimé ; le `.pbxproj` le référençait encore → recâblé
  automatiquement). 9 tests qui gardent la surface native v6 dont dépend le bridge
  (init builder, factories `PLYPresentationBuilder`, `PLYPresentationOutcome` +
  `closeReason`, enums interceptor/action, display modes).

### 2.7 Exemple

- `example/lib/main.dart` : `synchronize()` illustre la nouvelle sémantique
  (`await` + `try/catch`).

### 2.8 Documentation

- `MIGRATION-v6.md` mis à jour (callback `synchronize`, parité `closeReason`,
  `presentSubscriptions` retiré des deux côtés, pin natif rc1).
- Ce rapport (`V6_MIGRATION_REPORT.md`).

### 2.9 Finalisation API publique Dart — session 2026-06-24

**Ce qui a été fait :**

1. **Ajout des constructeurs nommés `PLYTransition.drawer()` et `.popin()`**
   (dans `lib/src/transition.dart`), symétriques de `.modal()` et `.fullScreen()`
   déjà existants. Paramètres : `height`, `width`, `dismissible`,
   `backgroundColors` (tous optionnels).

2. **Extension `Future<PLYPresentation>.display()`** (dans
   `lib/src/presentation.dart`) : permet de chaîner directement
   `.preload().display(transition)` sans `await` intermédiaire.

3. **Renames v5 → v6** (types supprimés ou renommés par rapport à la v5 de main) :

   | Ancien (v5) | Nouveau (v6) |
   |---|---|
   | `PresentPresentationResult` | `PLYPresentationOutcome` |
   | `PLYPaywallAction` | `PLYPresentationActionKind` |
   | `PLYPaywallInfo` | `PLYInterceptorInfo` |
   | `PLYPaywallActionParameters` | `PLYActionPayload` (+ sous-classes `PLY*Payload`) |
   | `PaywallActionInterceptorResult` | handler splité en `(PLYInterceptorInfo, PLYActionPayload?, PLYActionInterceptorHandler)` |

4. **`PLYRunningMode` simplifié** : l'ancienne version avait 4 valeurs
   (`transactionOnly`, `observer`, `paywallObserver`, `full`). La nouvelle n'en
   a que 2 : `observer` (index 0, défaut) et `full` (index 1). Tout code sur
   `transactionOnly` / `paywallObserver` doit être supprimé.

5. **`Purchasely.apiKey(…)` comme point d'entrée SDK** : l'init se fait via
   `Purchasely.apiKey('<key>').runningMode(…).start()` — le `PurchaselyBuilder`
   interne n'est pas référencé directement par l'utilisateur.

6. **Tests mis à jour** : `platform_channel_test.dart`, `purchasely_flutter_test.dart`,
   `bridge_test.dart`, `native_view_widget_test.dart`, `transition_test.dart`,
   `dart_android_bridge_test.dart`, `default_dismiss_handler_test.dart`,
   `interceptor_trigger_test.dart` — tous les types renommés, les assertions
   sur les valeurs obsolètes de `PLYRunningMode` corrigées.

**Résultat** : `flutter analyze` → 0 erreur, `flutter test` → 225 tests ✅.

---

## 3. API Dart v6 finale (référence pour `../Documentation` + `../purchasely-ai-skill`)

### Initialisation

```dart
final bool configured = await Purchasely.apiKey('<API_KEY>')
    .appUserId('user_id')                          // optionnel
    .runningMode(PLYRunningMode.full)              // observer (défaut) | full
    .logLevel(PLYLogLevel.error)                   // debug | info | warn | error
    .allowDeeplink(true)
    .allowCampaigns(true)                          // optionnel
    .stores([PLYStore.google])                     // Android : google | huawei | amazon
    .storekitVersion(PLYStorekitVersion.storeKit2) // iOS : storeKit2 (défaut) | storeKit1
    .start();
```

> **Le mode par défaut est `observer`** en v6. Passer `.runningMode(PLYRunningMode.full)`
> si Purchasely doit gérer/valider les achats.

### Affichage d'une présentation

```dart
final outcome = await PLYPresentationBuilder.placement('<PLACEMENT_ID>')
    .contentId('content_id')        // optionnel
    .onLoaded((p, err) {})          // optionnel
    .onPresented((p, err) {})       // optionnel
    .onCloseRequested(() {})        // optionnel
    .onDismissed((o) {})            // optionnel
    .build()
    .display(const PLYTransition.fullScreen()); // fullScreen | modal | push | drawer | popin

// PLYPresentationOutcome (5 champs) :
//   presentation, purchaseResult, plan (PLYPlan?), closeReason, error
```

Autres sources : `PLYPresentationBuilder.screen('<SCREEN_ID>')`,
`PLYPresentationBuilder.defaultSource()`. Cycle de vie :
`request.preload()` → `PLYPresentation` (avec `.display()`, `.close()`, `.back()`).

Pattern chaîné (preload + display en une expression) :

```dart
final outcome = await PLYPresentationBuilder.placement('<PLACEMENT_ID>')
    .build()
    .preload()
    .display(const PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.5)));
```

### Transitions dimensionnées

Constructeurs nommés disponibles sur `PLYTransition` :

| Constructeur | Description |
|---|---|
| `PLYTransition.fullScreen()` | Plein écran |
| `PLYTransition.modal({bool? dismissible})` | Modal sheet |
| `PLYTransition.push()` | Push / navigation |
| `PLYTransition.drawer({PLYTransitionDimension? height, bool? dismissible, PLYTransitionColors? backgroundColors})` | Drawer bas |
| `PLYTransition.popin({PLYTransitionDimension? width, PLYTransitionDimension? height, …})` | Pop-in flottant |

`PLYTransitionDimension` : `.pixel(value)` ou `.percentage(value)` (0.0–1.0).

### Action interceptor

```dart
await Purchasely.interceptAction(PLYPresentationActionKind.purchase, (info, payload) async {
  if (payload is PLYPurchasePayload) { /* … */ }
  return PLYInterceptResult.notHandled; // success | failed | notHandled
});
await Purchasely.removeActionInterceptor(PLYPresentationActionKind.purchase);
await Purchasely.removeAllActionInterceptors();
```

Kinds : `close, closeAll, login, navigate, purchase, restore, openPresentation,
openPlacement, promoCode, webCheckout`. Payloads typés : `PLYNavigatePayload`,
`PLYPurchasePayload`, `PLYClosePayload`, `PLYCloseAllPayload`,
`PLYOpenPresentationPayload`, `PLYOpenPlacementPayload`, `PLYWebCheckoutPayload`.

### Inline (embarqué)

```dart
final request = PLYPresentationBuilder.placement('inline').onDismissed((o) {}).build();
PLYPresentationView(request: request); // dans le widget tree
```

### Synchronize (nouveau comportement)

```dart
try {
  await Purchasely.synchronize(); // résout à la fin ; lève en cas d'échec
} catch (e) { /* PlatformException */ }
```

### Inchangé (source-compatible)

`purchaseWithPlanVendorId`, `signPromotionalOffer`, `restoreAllProducts`,
`silentRestoreAllProducts`, `userLogin`/`userLogout`, `isAnonymous`,
`anonymousUserId`, `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
`isEligibleForIntroOffer`, `userSubscriptions`/`userSubscriptionsHistory`,
`setUserAttribute*` (+ increment/decrement/clear), `listenToEvents`/`listenToPurchases`,
`setDynamicOffering`/`getDynamicOfferings`/…, `revokeDataProcessingConsent`,
`setLanguage`, `setThemeMode`, `setLogLevel`, `setDebugMode`,
`allowDeeplink`/`handleDeeplink` (les alias dépréciés ont été retirés).

No-op v6 (UI native supprimée) : `displaySubscriptionCancellationInstruction`.
(`presentSubscriptions` a été **retiré** — cf. §2.5.)

---

## 4. Contrat de canal (Dart ↔ natif)

- **MethodChannel `purchasely`** : `start`, `preload`, `display`, `close`, `back`,
  `registerInterceptor`, `removeInterceptor`, `removeAllInterceptors`,
  `interceptorResolve`, `synchronize`, + toute la surface conservée.
- **EventChannel `purchasely-presentation-events`** : `onLoaded`, `onPresented`,
  `onCloseRequested`, `onDismissed`, `interceptorTriggered` (chaque enveloppe porte
  un `requestId`).
- EventChannels existants : `purchasely-events`, `purchasely-purchases`,
  `purchasely-user-attributes`.

---

## 5. Vérifications exécutées (preuves)

| Vérification | Commande | Résultat |
|---|---|---|
| Dart analyze | `flutter analyze` | ✅ clean |
| Dart tests | `flutter test` | ✅ (suite complète, dont nouveaux tests `synchronize`) |
| Build Android | `flutter build apk --debug` (résout `6.0.0-rc.2` depuis **Maven Central**, sans mavenLocal) | ✅ `app-debug.apk` |
| Tests unit Android | `./gradlew :purchasely_flutter:testDebugUnitTest` | ✅ BUILD SUCCESSFUL |
| Build iOS | `xcodebuild … build` (`Purchasely 6.0.0-rc.2` depuis le **CocoaPods trunk**, sans dev-pod) | ✅ BUILD SUCCEEDED |
| Tests unit iOS | `xcodebuild test -only-testing:RunnerTests` (iPhone 17, iOS 26.5) | ✅ Executed 9 tests, 0 failures |
| Smoke iOS (réel, iPhone 17) | `flutter run` | ✅ SDK démarré, `Anonymous Id`, `is eligible: true`, `Product found`, dynamic offerings — backend réel ; UI rendue |
| Smoke Android (réel, Pixel_Tablet) | install APK + launch | ✅ `Initialization done`, `isSdkStarted=true`, `USER_LOGGED_IN userId=MY_USER_ID`, `Product found` — exemple Flutter, backend réel |
| **Présentation v6 de bout en bout (Android)** | tap « Display presentation » (placement `STRIPE`) | ✅ `PRESENTATION_LOADED` (type NORMAL) → `PRESENTATION_VIEWED` → **paywall `stripe_test` affiché plein écran** (0 crash) |

> Le run Flutter Android a d'abord buté sur `INSTALL_FAILED_INSUFFICIENT_STORAGE`
> (1er émulateur saturé par des apps utilisateur) puis a été finalisé sur le
> Pixel_Tablet. Le test d'affichage a révélé et permis de corriger le crash
> `PLYTransition` (conflit de version, cf. §2.4).

---

## 6. Fichiers modifiés (cette session)

- `purchasely/lib/purchasely_flutter.dart` — doc + sémantique `synchronize`.
- `purchasely/ios/Classes/SwiftPurchaselyFlutterPlugin.swift` — `from(screenId:)`,
  `PLYPresentationOutcome()`, `synchronize` callbacks, `presentSubscriptions` retiré,
  mapping `closeReason`, transitions modernes.
- `purchasely/ios/Classes/NativeView.swift` — `PLYPresentationOutcome()`.
- `purchasely/ios/purchasely_flutter.podspec` — pin `Purchasely 6.0.0-rc.2`.
- `purchasely/android/.../PurchaselyFlutterPlugin.kt` — `synchronize` callbacks,
  `PLYTransition` (args nommés + `PLYTransitionDimension`), imports.
- `purchasely/android/build.gradle`, `purchasely_google/android/build.gradle`,
  `purchasely_android_player/android/build.gradle` — pin `6.0.0-rc.2`.
- `purchasely/example/android/build.gradle` — `mavenLocal()` retiré.
- `purchasely/example/android/app/build.gradle` — pin `6.0.0-rc.2`.
- `purchasely/example/ios/Podfile` (+ `Podfile.lock`) — dev-pod retiré, résout
  `Purchasely 6.0.0-rc.2` depuis le trunk (plus de chemin absolu → commitable).
- `purchasely/test/platform_channel_test.dart` — tests `synchronize`.
- `purchasely/android/.../PurchaselyFlutterPluginTest.kt` — test `synchronize`.
- `purchasely/example/ios/RunnerTests/SwiftPurchaselyFlutterPluginTests.swift` — recréé.
- `purchasely/example/lib/main.dart` — exemple `synchronize`.
- `MIGRATION-v6.md`, `V6_MIGRATION_REPORT.md` — docs.

**Édition cross-repo** : `/Users/kevin/Purchasely/iOS/Purchasely.podspec` avait été
bumpé pour le dev-pod ; **revert à `3.6.2`** car le dev-pod n'est plus utilisé (résolution
depuis le trunk).

---

## 7. Doutes / points à reviewer (À LIRE)

1. **Version native (RÉSOLU).** Pin = **`6.0.0-rc.2`** (avec point) sur les deux
   plateformes, **réellement publié** : Android sur Maven Central
   (`repo1.maven.org/.../io/purchasely/core/6.0.0-rc.2/` → HTTP 200), iOS sur le
   CocoaPods trunk (`pod trunk info Purchasely` → `6.0.0-rc.2`, publié le 12/06/2026).
   Le projet builde donc depuis les dépôts publics (mavenLocal + dev-pod retirés) →
   le CI natif devrait passer. **Seul reste à trancher (release)** : `6.0.0` (GA) est
   sur Maven Central mais **pas encore sur CocoaPods trunk** — donc `6.0.0-rc.2` est
   la seule version cohérente cross-plateforme publiée aujourd'hui. Bumper vers
   `6.0.0` quand le pod GA sortira.

2. **Version du plugin Flutter (RÉSOLU).** Alignée sur le pré-release natif :
   `6.0.0-rc.2` (pubspecs des 3 packages, podspec, `sdkBridgeVersion` Kotlin/Swift,
   CHANGELOGs, VERSIONS.md, READMEs, `sdk_public_doc.md`). Bumper vers `6.0.0` en
   même temps que les natifs au GA.

3. **Podspec iOS local (RÉSOLU).** Le dev-pod `:path` a été retiré : iOS résout
   `Purchasely 6.0.0-rc.2` depuis le trunk. Le Podfile n'a plus de chemin absolu et
   est donc commité. (Le bump cross-repo du podspec iOS a été reverté.)

4. **Cohérence des versions natives `io.purchasely:*` (vérifier au merge).** Le
   crash `PLYTransition` venait d'un `6.0.0` perdu dans l'exemple. Avant merge,
   `grep -rn "io.purchasely:.*6\.0\.0\b" *` pour s'assurer qu'aucune référence ne
   pointe une autre version que `6.0.0-rc.2`. Idem quand la version finale sortira.

5. **`signPromotionalOffer` côté Android.** Non géré dans le `when` du bridge Android
   (renvoie `notImplemented`) — comportement pré-existant (offres promo Apple = iOS).
   Pas dans le scope de la migration, mais à confirmer si une parité est attendue.

6. **`contentId` de présentation chargée sur iOS.** Toujours `null` côté iOS
   (`PLYPresentation` ne l'expose pas en natif). Android le renvoie. Documenté.

7. **Warning iOS résiduel.** `setThemeMode` est déprécié côté natif (« removed in
   v7.0 »), mais conservé car méthode v5 toujours fonctionnelle. À remplacer par le
   modifier `.themeMode()` du builder lors d'une future passe.

---

## 8. Pour mettre à jour `../Documentation` et `../purchasely-ai-skill`

- `purchasely-ai-skill/references/flutter/integration.md` : encore en **v5**
  (`Purchasely.start(...)`, `fetchPresentation`/`presentPresentation`,
  `setPaywallActionInterceptorCallback` + `onProcessAction`). À remplacer par
  l'API v6 (§3) : `Purchasely.apiKey(…)`, `PLYPresentationBuilder` /
  `PLYPresentationRequest`, `Purchasely.interceptAction`, `PLYPresentationView`,
  `synchronize` awaitable. **Tous les types doivent porter le préfixe `PLY`**
  (cf. §2.9 — BREAKING depuis le 2026-06-24).
- Créer `purchasely-ai-skill/references/flutter/migration-v6.md` (analogue
  Android/iOS) à partir de `MIGRATION-v6.md` (déjà à jour avec les noms PLY).
- `purchasely-ai-skill/references/sdk-versions.md` : Flutter passe de `5.7.3` à
  `6.0.0-rc.2` (plugin), natifs `6.0.0-rc.2`.
- Docs publiques (`../Documentation`) : guide d'intégration Flutter + guide de
  migration 5→6 Flutter, en miroir des guides Android/iOS. Utiliser les noms
  PLY-préfixés de §3 et `MIGRATION-v6.md`.
