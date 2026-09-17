# Handoff

## Current work

Adding the iOS-only `refundHandling` data processing purpose to the Flutter plugin.

## Current state

The feature branch is created from `origin/main`. Source, bridge, tests, and changelog
edits are complete. Flutter 3.24.5 is installed at `/Users/devin/flutter`; package
verification passed.

## Next actions

Commit and push the feature branch. The iOS RunnerTests target has no existing method-call
driving helper, so the requested native consent tests were skipped.

## Key decisions

- Keep Android untouched and leave native SDK dependency pins at 6.1.0.
- Do not add documentation sections where the public docs have no existing purpose listing.
