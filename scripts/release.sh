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
GEM_DIR="${GEM_NAME}"  # folder where the gem lives (same as the gem name)
VERSION_FILE="${GEM_DIR}/lib/${GEM_NAME//-//}/version.rb"
TAG_PREFIX="${GEM_NAME}_v"
GEM_FURY_URL="https://${GEM_FURY_PUSH_TOKEN}@push.fury.io/yousty-ag/"

# === STEP 1: BUMP VERSION ===
# echo "🔢 Bumping version for ${GEM_NAME} (${BUMP_ARGUMENT})..."
pushd "${GEM_DIR}" > /dev/null
bump "${BUMP_ARGUMENT}" --tag --tag-prefix "${TAG_PREFIX}"
VERSION=$(bump current | tail -n 1)
popd > /dev/null
# echo "📦 New version for ${GEM_NAME}: ${VERSION}"

# === STEP 2: CREATE GIT TAG ===
# Create git tag
TAG_NAME="${TAG_PREFIX}${VERSION}"
echo "🏷️  Creating git tag ${TAG_NAME}..."
git tag "${TAG_NAME}"

# === STEP 2: BUILD GEM ===
echo "🏗️  Building ${GEM_NAME}.gem..."
pushd "${GEM_DIR}" > /dev/null
gem build "${GEM_NAME}.gemspec"
popd > /dev/null

# === STEP 4: PUSH TO GEM FURY ===
echo "🚀 Uploading ${GEM_NAME}-${VERSION}.gem to Gemfury..."
curl -F "package=@${GEM_DIR}/${GEM_NAME}-${VERSION}.gem" "${GEM_FURY_URL}"

# === STEP 5: CLEANUP ===
echo "🧹 Cleaning up built gem..."
rm "${GEM_DIR}/${GEM_NAME}-${VERSION}.gem"

# === STEP 6: COMMIT AND PUSH ===
echo "📤 Committing and pushing changes..."
git add "${VERSION_FILE}"
git commit -m "Release ${GEM_NAME} v${VERSION}"
git push origin "$(git branch --show-current)"
git push origin --tags

echo "✅ Release complete: ${GEM_NAME} v${VERSION}"