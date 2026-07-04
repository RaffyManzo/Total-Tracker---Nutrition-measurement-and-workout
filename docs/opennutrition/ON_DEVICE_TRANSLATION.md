# OpenNutrition on-device translation

Total Tracker uses `google_mlkit_translation` only for the optional
OpenNutrition static-index source.

## Runtime behavior

- The device language is read from the active platform locale.
- User queries are translated to English before static-shard routing.
- Result names are translated from English to the device language.
- Translation text is processed by the native ML Kit API on the device.
- Language models are downloaded only when needed and require Wi-Fi.
- A missing model, unsupported language or unsupported platform produces an
  explicit OpenNutrition error rather than silently using a cloud translator.
- Open Food Facts remains the primary online source.

## Supported project platforms

The current repository has a complete Android project and an incomplete iOS
scaffold. Phase 4E therefore updates Android requirements only. iOS must not be
advertised as supported until a real Podfile and Xcode project are restored and
configured with deployment target 15.5 or newer and armv7 excluded.

## Attribution and disclaimer

Translated results are marked adjacent to their source as automatic
translations with Google Translate. The settings page links to Google Translate
and states that automatic translations may contain errors and are provided
without accuracy guarantees.

References:

- https://pub.dev/packages/google_mlkit_translation
- https://developers.google.com/ml-kit/language/translation/translation-terms
- https://translate.google.com/
