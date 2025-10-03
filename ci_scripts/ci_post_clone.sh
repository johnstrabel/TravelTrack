#!/bin/sh

# Install Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install dependencies
flutter precache --ios
flutter pub get

# Build iOS
cd ios
pod install

