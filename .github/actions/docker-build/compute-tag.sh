#!/usr/bin/env bash
# Versioning logic for Docker image tags.
# Implements: format_version, version_regex, increment_version, registry tag query.
#
# Required env:
#   VERSION — raw version from source (e.g. 1.2.3 or 0.1.2)
#   IMAGE_NAME — image name (e.g. gateway, nix)
#   IMAGE_SUB_PATH — path in registry (e.g. apps/back, apps/front)
#   REGISTRY — registry address
#   REGISTRY_USERNAME
#   REGISTRY_PASSWORD
#   TEST_RELEASE — "true" to force release logic regardless of branch
#
# Writes to $GITHUB_OUTPUT:
#   image_tag, is_release, cache_from, cache_to
set -euo pipefail

# Appends 000 to the last numeric component of the version.
# This is the "base" from which sequential tags are counted.
#   1.2.3 -> 1.2.3000  (patch becomes 4-digit: 3 -> 3000)
#   0.1   -> 0.1000    (minor becomes 4-digit: 1 -> 1000)
#
# BASH_REMATCH is populated by the =~ operator and contains capture groups:
#   [1]=major [2]=minor [3]=patch (optional) [4]=suffix e.g. -beta (optional)
format_version() {
  local v="$1"
  if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-[^[:space:]]+)?$ ]]; then
    printf '%s.%s.%s000%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
  elif [[ "$v" =~ ^([0-9]+)\.([0-9]+)(-[^[:space:]]+)?$ ]]; then
    printf '%s.%s000%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  else
    echo "::error::Invalid version '$v'. Expected X.Y.Z[-suffix] or X.Y[-suffix]" >&2; exit 1
  fi
}

# Builds an ERE (Extended Regular Expression) that matches all sequential tags
# for a given base version. Used to filter registry tags before sorting.
#
# The last numeric component is replaced with [0-9]{3} to match exactly
# 3 trailing digits — the increment counter (000..999):
#   1.2.3 -> ^1\.2\.3[0-9]{3}$   matches 1.2.3000, 1.2.3001, ..., 1.2.3999
#   0.1   -> ^0\.1[0-9]{3}$      matches 0.1000, 0.1001, ..., 0.1999
#
# Dots are escaped as \\. because this regex is passed to grep -E,
# where a bare dot means "any character".
version_regex() {
  local v="$1"
  if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-[^[:space:]]+)?$ ]]; then
    local suf="${BASH_REMATCH[4]}"
    # Ternary via && / ||: if suffix is non-empty, include it in the pattern
    [[ -n "$suf" ]] \
      && printf '^%s\\.%s\\.%s[0-9]{3}%s$' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${suf}" \
      || printf '^%s\\.%s\\.%s[0-9]{3}$' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  elif [[ "$v" =~ ^([0-9]+)\.([0-9]+)(-[^[:space:]]+)?$ ]]; then
    local suf="${BASH_REMATCH[3]}"
    [[ -n "$suf" ]] \
      && printf '^%s\\.%s[0-9]{3}%s$' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${suf}" \
      || printf '^%s\\.%s[0-9]{3}$' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  fi
}

# Increments the last numeric component by 1, keeping 4-digit zero-padding.
#   1.2.3001 -> 1.2.3002
#   0.1005   -> 0.1006
#
# 10# prefix forces bash to treat the number as decimal.
# Without it, a value like 0008 would be interpreted as invalid octal.
#
# printf '%04d' pads the result back to 4 digits (e.g. 9 -> 0009).
increment_version() {
  local v="$1"
  if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-[^[:space:]]+)?$ ]]; then
    printf '%s.%s.%s%s' \
      "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" \
      "$(printf '%04d' $(( 10#${BASH_REMATCH[3]} + 1 )))" "${BASH_REMATCH[4]}"
  elif [[ "$v" =~ ^([0-9]+)\.([0-9]+)(-[^[:space:]]+)?$ ]]; then
    printf '%s.%s%s' \
      "${BASH_REMATCH[1]}" \
      "$(printf '%04d' $(( 10#${BASH_REMATCH[2]} + 1 )))" "${BASH_REMATCH[3]}"
  fi
}

# Release branch: main or 1-2 digit numeric branch (e.g. 9, 22)
IS_RELEASE=false
if [[ "${TEST_RELEASE:-false}" == "true" ]] || [[ "$GITHUB_REF_NAME" =~ ^(main|[0-9]{1,2})$ ]]; then
  IS_RELEASE=true
fi
echo "Release build: $IS_RELEASE (ref: $GITHUB_REF_NAME)"

BASE_VERSION=$(format_version "$VERSION")
echo "Base version: $BASE_VERSION"

if [[ "$IS_RELEASE" == "true" ]]; then
  REGEX=$(version_regex "$VERSION")
  echo "Registry query: ${REGISTRY}/${IMAGE_SUB_PATH}/${IMAGE_NAME} regex: $REGEX"

  # skopeo list-tags returns JSON: {"Repository":"...","Tags":["1.2.3000","1.2.3001",...]}
  # 2>&1 captures stderr into RAW so we can inspect auth errors below.
  # || true prevents the script from exiting if the image doesn't exist yet.
  RAW=$(skopeo list-tags \
    --username "$REGISTRY_USERNAME" \
    --password "$REGISTRY_PASSWORD" \
    "docker://${REGISTRY}/${IMAGE_SUB_PATH}/${IMAGE_NAME}" 2>&1 || true)

  # Distinguish auth failure (wrong credentials) from "image not found yet".
  # Auth errors must be fatal — otherwise we'd silently fall back to base version
  # and risk overwriting an existing tag on the next push.
  if echo "$RAW" | grep -qiE 'unauthorized|401|forbidden|403'; then
    echo "::error::Registry authentication failed." >&2; exit 1
  fi

  # Pipeline to find the latest matching tag:
  #   jq — extract tag strings from JSON array (.Tags[]?)
  #        '// empty' means: if Tags is null/missing, produce no output
  #   grep -vE — drop service tags (cache layers, snapshots) — not real releases
  #   grep -E — keep only tags matching current version (e.g. ^1\.2\.3[0-9]{3}$)
  #   sort — lexicographic sort works correctly for zero-padded numbers
  #   tail -1 — pick the highest tag
  LATEST=$(echo "$RAW" \
    | jq -r '.Tags[]? // empty' 2>/dev/null \
    | grep -vE 'cache|snapshot' \
    | { grep -E "$REGEX" || true; } \
    | sort | tail -1)

  if [[ -n "$LATEST" ]]; then
    echo "Latest tag: $LATEST"
    IMAGE_TAG=$(increment_version "$LATEST")
  else
    echo "No existing tags — first push, using base version"
    IMAGE_TAG="$BASE_VERSION"
  fi

  # No cache on release builds — avoids polluting the cache layer
  # with release artifacts and keeps release images clean.
  CACHE_FROM=""
  CACHE_TO=""
else
  IMAGE_TAG="${BASE_VERSION}-snapshot"
  # Cache is stored as a separate tag alongside the image: <tag>-cache
  # mode=max caches all intermediate layers, not just the final one.
  # image-manifest=true stores cache as a regular OCI image (required by some registries).
  CACHE_REF="${REGISTRY}/${IMAGE_SUB_PATH}/${IMAGE_NAME}:${IMAGE_TAG}-cache"
  CACHE_FROM="type=registry,ref=${CACHE_REF}"
  CACHE_TO="type=registry,ref=${CACHE_REF},mode=max,image-manifest=true"
fi

echo "Image tag: $IMAGE_TAG"

# GITHUB_OUTPUT is a file path provided by the runner.
# Writing KEY=VALUE lines to it makes values available in subsequent steps
# as ${{ steps.<id>.outputs.KEY }}.
{
  echo "image_tag=${IMAGE_TAG}"
  echo "is_release=${IS_RELEASE}"
  echo "cache_from=${CACHE_FROM}"
  echo "cache_to=${CACHE_TO}"
} >> "$GITHUB_OUTPUT"
