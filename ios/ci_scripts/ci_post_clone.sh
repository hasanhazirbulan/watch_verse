#!/bin/sh
set -e
set -x

# Xcode Cloud clones the repo fresh with no Flutter SDK or CocoaPods present,
# so this script has to bootstrap both before xcodebuild can archive anything
# — without it, Xcode Cloud never generates ios/Flutter/Generated.xcconfig or
# runs `pod install`, so the archive fails immediately looking for files that
# don't exist yet. Pinned to the same Flutter version as
# .github/workflows/ci.yml for consistency.
git clone https://github.com/flutter/flutter.git -b 3.47.6 "$HOME/flutter" --depth 1
export PATH="$PATH:$HOME/flutter/bin"

flutter precache --ios
flutter pub get

HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd "$CI_PRIMARY_REPOSITORY_PATH/ios" && pod install
