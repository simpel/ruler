#!/bin/bash
# Tools/bump-version.sh
#
# Analyzes git history using Conventional Commits to automatically calculate
# and bump the app version (CFBundleShortVersionString) and build number
# (CFBundleVersion) in Resources/Info.plist.
#
# Usage:
#   ./Tools/bump-version.sh [--bump auto|patch|minor|major|X.Y.Z] [--build <n>] [--write] [--dry-run]
#
set -euo pipefail

cd "$(dirname "$0")/.."

INFO_PLIST="Resources/Info.plist"
[ -f "$INFO_PLIST" ] || { echo "error: $INFO_PLIST not found" >&2; exit 1; }

BUMP_TYPE="auto"
BUILD_ARG=""
DO_WRITE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump)
      BUMP_TYPE="$2"
      shift 2
      ;;
    --build)
      BUILD_ARG="$2"
      shift 2
      ;;
    --write)
      DO_WRITE=true
      shift
      ;;
    --dry-run)
      DO_WRITE=false
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--bump auto|patch|minor|major|X.Y.Z] [--build <number>] [--write] [--dry-run]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Read current plist values
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1")

# Find latest git tag (vX.Y.Z)
LATEST_TAG=$(git describe --tags --abbrev=0 --match "v[0-9]*" 2>/dev/null || echo "")

if [ -n "$LATEST_TAG" ]; then
  TAG_VERSION="${LATEST_TAG#v}"
else
  TAG_VERSION="$CURRENT_VERSION"
fi

# Version comparison function: returns 0 if $1 > $2
version_gt() {
  local v1=(${1//./ })
  local v2=(${2//./ })
  local maj1=${v1[0]:-0} min1=${v1[1]:-0} pat1=${v1[2]:-0}
  local maj2=${v2[0]:-0} min2=${v2[1]:-0} pat2=${v2[2]:-0}
  if [ "$maj1" -gt "$maj2" ]; then return 0; fi
  if [ "$maj1" -lt "$maj2" ]; then return 1; fi
  if [ "$min1" -gt "$min2" ]; then return 0; fi
  if [ "$min1" -lt "$min2" ]; then return 1; fi
  if [ "$pat1" -gt "$pat2" ]; then return 0; fi
  return 1
}

# Base version to calculate from: take the higher of TAG_VERSION and CURRENT_VERSION
BASE_VERSION="$TAG_VERSION"
if version_gt "$CURRENT_VERSION" "$TAG_VERSION"; then
  BASE_VERSION="$CURRENT_VERSION"
fi

# Split BASE_VERSION into major, minor, patch
IFS='.' read -r BASE_MAJOR BASE_MINOR BASE_PATCH <<< "$BASE_VERSION"
BASE_MAJOR=${BASE_MAJOR:-1}
BASE_MINOR=${BASE_MINOR:-0}
BASE_PATCH=${BASE_PATCH:-0}

NEW_VERSION=""
RESOLVED_BUMP=""

# Check if explicit version passed (e.g. 1.7.0)
if [[ "$BUMP_TYPE" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  NEW_VERSION="$BUMP_TYPE"
  RESOLVED_BUMP="explicit"
elif [ "$BUMP_TYPE" = "major" ]; then
  NEW_VERSION="$((BASE_MAJOR + 1)).0.0"
  RESOLVED_BUMP="major"
elif [ "$BUMP_TYPE" = "minor" ]; then
  NEW_VERSION="${BASE_MAJOR}.$((BASE_MINOR + 1)).0"
  RESOLVED_BUMP="minor"
elif [ "$BUMP_TYPE" = "patch" ]; then
  NEW_VERSION="${BASE_MAJOR}.${BASE_MINOR}.$((BASE_PATCH + 1))"
  RESOLVED_BUMP="patch"
elif [ "$BUMP_TYPE" = "auto" ]; then
  # Auto-detect based on conventional commits since LATEST_TAG
  if [ -n "$LATEST_TAG" ]; then
    COMMITS=$(git log "${LATEST_TAG}..HEAD" --format="%s%n%b" 2>/dev/null || echo "")
  else
    COMMITS=$(git log --format="%s%n%b" 2>/dev/null || echo "")
  fi

  if [ -z "$COMMITS" ]; then
    # No new commits since tag
    NEW_VERSION="$BASE_VERSION"
    RESOLVED_BUMP="none"
  elif echo "$COMMITS" | grep -q -E "(^BREAKING CHANGE:|^BREAKING-CHANGE:|^[a-zA-Z]+(\([^\)]+\))?!:)"; then
    NEW_VERSION="$((BASE_MAJOR + 1)).0.0"
    RESOLVED_BUMP="major (breaking change)"
  elif echo "$COMMITS" | grep -q -E "^feat(\([^\)]+\))?:"; then
    NEW_VERSION="${BASE_MAJOR}.$((BASE_MINOR + 1)).0"
    RESOLVED_BUMP="minor (feature)"
  else
    NEW_VERSION="${BASE_MAJOR}.${BASE_MINOR}.$((BASE_PATCH + 1))"
    RESOLVED_BUMP="patch (fixes/chores/other)"
  fi
else
  echo "error: invalid bump type '$BUMP_TYPE'. Expected auto, patch, minor, major, or X.Y.Z" >&2
  exit 1
fi

# Calculate build number
if [ -n "$BUILD_ARG" ]; then
  NEW_BUILD="$BUILD_ARG"
else
  NEW_BUILD=$((CURRENT_BUILD + 1))
fi

echo "Current version : $CURRENT_VERSION (build $CURRENT_BUILD)"
echo "Latest git tag  : ${LATEST_TAG:-none}"
echo "Bump resolution : $RESOLVED_BUMP"
echo "Target version  : $NEW_VERSION (build $NEW_BUILD)"

if [ "$DO_WRITE" = true ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$INFO_PLIST"
  echo "Updated $INFO_PLIST -> CFBundleShortVersionString=$NEW_VERSION, CFBundleVersion=$NEW_BUILD"
fi
