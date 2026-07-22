#!/bin/sh
newMajor="$(date -u +%Y%m%d)"
date24H=$(date -u +%H%M)
tmpMinor=$(printf "%x\n" $(echo $date24H | sed 's/^0*//'))
newMinor=$(echo $tmpMinor | tr '[:lower:]' '[:upper:]')
newBuildNumber="$newMajor-$newMinor"

## create folder to hold exported app
shortVer="v${MARKETING_VERSION}"
exeName="${EXECUTABLE_NAME}"
buildDir="/Users/lesliehelou/Documents/Travel/- Projects/$exeName/$shortVer/"

if [ ! -d "$buildDir" ];then
    mkdir -p "$buildDir"
fi

shortVer="v${MARKETING_VERSION}"
exeName="${EXECUTABLE_NAME}"
buildDir="/Users/lesliehelou/Documents/Travel/- Projects/$exeName/$shortVer/"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $newBuildNumber" "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Contents/Info.plist"

## remove extended attributes (from added images)
/usr/bin/xattr -cr "${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Contents/Resources"


