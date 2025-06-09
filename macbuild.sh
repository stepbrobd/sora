#!/bin/bash

set -e

cd "$(dirname "$0")"

WORKING_LOCATION="$(pwd)"
APPLICATION_NAME=Sulfur

if [ ! -d "build" ]; then
    mkdir build
fi

cd build

xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Release \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp_arm64" \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    -arch arm64 \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"

xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Release \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp_x86_64" \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    -arch x86_64 \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"

ARM64_APP_PATH="$WORKING_LOCATION/build/DerivedDataApp_arm64/Build/Products/Release-maccatalyst/$APPLICATION_NAME.app"
X86_64_APP_PATH="$WORKING_LOCATION/build/DerivedDataApp_x86_64/Build/Products/Release-maccatalyst/$APPLICATION_NAME.app"
TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"

cp -r "$ARM64_APP_PATH" "$TARGET_APP"

lipo -create \
    "$ARM64_APP_PATH/Contents/MacOS/$APPLICATION_NAME" \
    "$X86_64_APP_PATH/Contents/MacOS/$APPLICATION_NAME" \
    -output "$TARGET_APP/Contents/MacOS/$APPLICATION_NAME"

codesign --remove "$TARGET_APP"
if [ -e "$TARGET_APP/_CodeSignature" ]; then
    rm -rf "$TARGET_APP/_CodeSignature"
fi

echo "Mac Catalyst universal binary build completed: $TARGET_APP"
lipo -info "$TARGET_APP/Contents/MacOS/$APPLICATION_NAME"
