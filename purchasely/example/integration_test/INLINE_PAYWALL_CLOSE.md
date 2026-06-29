# Fermeture (croix ✕) d'un paywall inline (`PLYPresentationView`)

Document issu d'une investigation E2E réelle (émulateur Android `emulator-5554` +
simulateur iOS iPhone 16e, SDK natif `6.0.0-rc.2`), vérifiée **dans l'app réelle**
(`flutter run`) sur les deux plateformes.

## TL;DR — trois conditions, toutes nécessaires

Pour qu'un clic sur la croix ✕ d'un paywall **inline** ferme la vue :

1. **(Plugin) Hybrid composition** — la vue native doit être embarquée en hybrid
   composition, sinon **aucune touche** n'atteint le paywall embarqué (ni croix, ni
   boutons d'achat). C'est LA cause de fond du « rien ne se passe ». Corrigé dans
   `lib/native_view_widget.dart` (voir plus bas).
2. **(Backend) Action `close` sur une vue non-Flow** — la croix doit porter l'action
   `close` (fermeture d'écran simple), **pas `close_all`**, et le paywall **ne doit pas
   être un Flow**.
3. **(App) Gérer `onCloseRequested` + pop unique** — l'hôte retire la vue. La fermeture
   émet `onCloseRequested` **puis** `onDismissed` : ne dépiler qu'**une fois**.

## Cause de fond #1 — transmission des touches (le vrai bug)

Le plugin rendait la vue inline via un `AndroidView` simple (mode *virtual display*).
Dans ce mode, les `MotionEvent` ne sont **pas** délivrés de façon fiable aux vues
interactives embarquées : taper la croix **ou** un bouton d'achat ne produisait
**aucune** réaction du SDK (vérifié : aucun event entre `PRESENTATION_VIEWED` et le
`dispose`).

Correctif (`lib/native_view_widget.dart`) : **hybrid composition** via
`PlatformViewLink` + `PlatformViewsService.initExpensiveAndroidView` (la vue native vit
dans la hiérarchie Android, les touches arrivent nativement) + un `EagerGestureRecognizer`
pour que la platform view capte les gestes. iOS (`UiKitView`) transmet déjà les touches
nativement, aucun changement requis.

> Note : ce bug n'est **pas** reproductible dans l'environnement `integration_test`
> (le harness ne pilote pas l'input natif des platform views via `adb`/`idb`).
> Vérification de la fermeture = app réelle (`flutter run`).

### Pourquoi la fermeture inline n'est pas automatisable en `integration_test` (preuve empirique)

Une tentative de suite E2E a été menée (driver host-side `tap_close_inline.sh` lancé
en parallèle d'un `integration_test` montant la `PLYPresentationView`, placement
`promo_offers`). Résultat **reproductible** sur émulateur Android (Pixel Tablet,
SDK natif `6.0.0-rc.2`) :

- le rendu fonctionne : **`onPresented` se déclenche** (la vue embarquée s'affiche) ;
- le driver tape la **bonne** coordonnée du ✕ (vérifié par screenshot : `action:close`
  à `(2504,216)`, soit la croix haut-droite), **8 fois** ;
- pourtant **`onCloseRequested` n'est jamais reçu** côté Dart.

`onPresented` (event de cycle de vie poussé par le SDK) passe, mais le **tap** ne
produit aucun `onCloseRequested` → le tap `adb` **n'atteint pas la vue embarquée
comme un geste interactif** sous instrumentation `integration_test`. C'est cohérent
avec le fait que le binding de test Flutter possède le routage des pointeurs de sa
propre fenêtre, alors que le forwarding hybrid-composition (Android) / `UiKitView`
(iOS) ne se comporte pas comme en production.

> Contraste : les suites `interceptor` / `dismiss` tapent des paywalls **modaux**
> (fenêtres natives séparées, hors compositeur Flutter) — là, `adb`/`idb` atteint
> bien la cible. C'est spécifique à la vue **embarquée**.

**Comment tester la fermeture inline alors :**
1. Manuellement via `flutter run` sur device réel (chemin retenu, cf. ci-dessous).
2. Via un harness piloté **hors** `integration_test` (Appium / le repo `Mobile-UITests`),
   qui injecte de vrais évènements tactiles au niveau OS sans le binding de test Flutter.

## Cause #2 — action de la croix (config Console)

| Action de la croix ✕ | Inline | `onCloseRequested` ? |
|---|---|---|
| `close` (fermeture simple) | ✅ notifie l'hôte | ✅ oui |
| `close_all` (`closeAllScreens`) | ❌ ferme des activités/écrans modaux → no-op embarqué | ❌ non |
| `open_flow_step` (paywall **Flow**) | ❌ non supporté inline (« must call display()/getFragment() ») | ❌ non |

Validation objective : un dump uiautomator de la vue inline montre
`content-desc="action:close"` (et `flowId=null` dans `PRESENTATION_LOADED`).

## Cause #3 — double pop côté app

La fermeture inline émet **`onCloseRequested`** (le ✕ demande la fermeture) **puis**,
une fois la vue retirée, **`onDismissed`**. Si les deux callbacks dépilent la route, le
second pop ferme aussi l'écran sous-jacent → écran noir. `main.dart`
(`displayPresentationInline`) utilise une garde `popped` pour ne dépiler qu'une fois.

## Chaîne native Android (référence)

```
Builder.onCloseRequested { emit("onCloseRequested") }   (plugin, buildPrepared)
  → preload() → Loaded.onCloseRequested
  → buildView() → viewRequest.onCloseRequested           (PLYPresentationDisplayController:70)
  → PLYPresentationView lit requestLoaded.onCloseRequested (PLYPresentationView:206)
  → close() invoque callbackPaywallCloseRequested          (PLYPresentationView:336)
```
`close()` n'est atteint que par l'action `close` ; `close_all` passe par
`Purchasely.closeAllScreens()` (activités) → no-op pour une vue embarquée.

## Résultat vérifié (app réelle)

Android et iOS : ouverture inline → tap croix ✕ → logs
`close requested (inline)` → `popping inline screen` → `dismissed (cancelled)` →
retour à l'écran d'accueil. ✓

## Fichiers

- `lib/native_view_widget.dart` — hybrid composition (Android).
- `example/lib/presentation_screen.dart` — câble `onCloseRequested`/`onDismissed`, contenu au-dessus/en-dessous.
- `example/lib/main.dart` — `displayPresentationInline` avec garde anti-double-pop.
- `example/integration_test/inline_paywall_test.dart` — test E2E de **rendu** inline (le rendu est testable en harness ; la fermeture native ne l'est pas).
