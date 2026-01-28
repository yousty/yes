#!/usr/bin/env bash
set -euo pipefail

# === USAGE CHECK ===
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <gem-name> <bump-type>"
  echo "Example: $0 yes-read-api patch"
  exit 1
fi

# === ARGUMENTS ===
GEM_NAME="$1"
BUMP_ARGUMENT="$2"

# === CONFIGURATION ===
# If gem name is "yes", use current directory; otherwise use gem name as subdirectory
if [ "${GEM_NAME}" = "yes" ]; then
  GEM_DIR=""
  VERSION_FILE="lib/${GEM_NAME//-//}/version.rb"
else
  GEM_DIR="${GEM_NAME}"
  VERSION_FILE="${GEM_DIR}/lib/${GEM_NAME//-//}/version.rb"
fi
TAG_PREFIX="${GEM_NAME}-v"
GEM_FURY_URL="https://${GEM_FURY_PUSH_TOKEN}@push.fury.io/yousty-ag/"

# === STEP 1: BUMP VERSION ===
# echo "🔢 Bumping version for ${GEM_NAME} (${BUMP_ARGUMENT})..."
if [ -n "${GEM_DIR}" ]; then
  pushd "${GEM_DIR}" > /dev/null
fi
bump "${BUMP_ARGUMENT}" --tag --tag-prefix "${TAG_PREFIX}"
VERSION=$(bump current | tail -n 1)
if [ -n "${GEM_DIR}" ]; then
  popd > /dev/null
fi
# echo "📦 New version for ${GEM_NAME}: ${VERSION}"

# === STEP 2: CREATE GIT TAG ===
# Create git tag
TAG_NAME="${TAG_PREFIX}${VERSION}"
echo "🏷️  Creating git tag ${TAG_NAME}..."
git tag "${TAG_NAME}"

# === STEP 2: BUILD GEM ===
echo "🏗️  Building ${GEM_NAME}.gem..."
if [ -n "${GEM_DIR}" ]; then
  pushd "${GEM_DIR}" > /dev/null
fi
gem build "${GEM_NAME}.gemspec"
if [ -n "${GEM_DIR}" ]; then
  popd > /dev/null
fi

# === STEP 4: PUSH TO GEM FURY ===
echo "🚀 Uploading ${GEM_NAME}-${VERSION}.gem to Gemfury..."
if [ -n "${GEM_DIR}" ]; then
  GEM_FILE="${GEM_DIR}/${GEM_NAME}-${VERSION}.gem"
else
  GEM_FILE="${GEM_NAME}-${VERSION}.gem"
fi
curl -F "package=@${GEM_FILE}" "${GEM_FURY_URL}"

# === STEP 5: CLEANUP ===
echo "🧹 Cleaning up built gem..."
rm "${GEM_FILE}"

# === STEP 6: COMMIT AND PUSH ===
echo "📤 Committing and pushing changes..."
git add "${VERSION_FILE}"
git commit -m "Release ${GEM_NAME} v${VERSION}"
git push origin "$(git branch --show-current)"
git push origin --tags

echo "✅ Release complete: ${GEM_NAME} v${VERSION}"