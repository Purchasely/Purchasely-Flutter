## Description

<!-- Provide a brief description of the changes in this PR -->

## Type of Change

<!-- Mark the relevant option with an 'x' -->

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📦 SDK Version Update (updating native SDK dependencies)
- [ ] 📚 Documentation update
- [ ] 🔧 Configuration/CI change

## SDK Version Update Checklist

<!-- Complete this section if updating SDK versions -->

- [ ] Updated `VERSIONS.md` with new version entry
- [ ] Updated `purchasely/pubspec.yaml` version
- [ ] Updated `purchasely/CHANGELOG.md` with changes
- [ ] Updated iOS SDK version in `purchasely/ios/purchasely_flutter.podspec`
- [ ] Updated Android SDK version in `purchasely/android/build.gradle`
- [ ] Ran `flutter pub get` in `purchasely/`
- [ ] Ran `pod update` in `purchasely/example/ios/`
- [ ] Updated `purchasely_google/pubspec.yaml` version (if applicable)
- [ ] Updated `purchasely_android_player/pubspec.yaml` version (if applicable)

## Testing

<!-- Describe the tests you ran -->

- [ ] iOS example app builds successfully (`flutter build ios --simulator`)
- [ ] Android example app builds successfully (`flutter build apk`)
- [ ] Unit tests pass (`flutter test`)
- [ ] Manually tested on iOS simulator/device
- [ ] Manually tested on Android emulator/device

## Checklist

- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code where necessary
- [ ] I have updated the documentation accordingly
- [ ] My changes generate no new warnings
- [ ] All CI checks pass

## Related Issues

<!-- Link any related issues here -->

Closes #

## Screenshots/Videos (if applicable)

<!-- Add screenshots or videos to help explain your changes -->

## Additional Notes

<!-- Any additional information that reviewers should know -->