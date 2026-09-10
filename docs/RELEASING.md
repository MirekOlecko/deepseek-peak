# Release checklist

Goal: publish the existing desktop/menu bar widget as source and a downloadable
universal application for macOS 13 or later. Preserve the current interface.

1. Check DeepSeek's official pricing schedule. Document that this app calculates
   a local schedule, not account charges, and is not affiliated with DeepSeek.
2. Review the staged source: exclude local builds, original Xcode starter project,
   personal settings, credentials and signing assets. Use a GitHub noreply author.
3. Run `swift test`. Build using `./scripts/build-app.sh release`; the script
   increments CFBundleVersion before compilation and builds both architectures.
4. Verify both slices with `lipo`, the signature with `codesign`, the macOS minimum
   with `vtool`, and render compact/expanded previews. Test the x86_64 executable
   under Rosetta when available; this does not replace an Intel hardware test.
5. Run `./scripts/package-release.sh`. This only packages an existing build.
   Check the ZIP/DMG contents and SHA256 sums before uploading release assets.
6. Commit reviewed source, tag the version and publish the GitHub release.
   Verify that release assets can be fetched without authentication.

The initial release is ad-hoc signed and **not notarized**. State this prominently
in the README and release notes. Do not claim Apple verification or instruct users
to disable Gatekeeper globally. Document Apple's per-app Open Anyway procedure.
A future Developer ID signed/notarized release requires a suitable certificate
and notarization credentials; never commit either to Git.

No updater, analytics, account integration or new networking is introduced.
Pushing source and publishing the release are authorized by the project owner.
