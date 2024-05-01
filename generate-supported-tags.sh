#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMIT_ID="$(git rev-parse --verify HEAD)"
DISTS=('alpine' 'debian')
JSON="$(cat ./versions.json)"
LATEST_VERSIONS_KEYS=()
LEGACY_VERSIONS_KEYS=()
REPOSITORY='https://github.com/dstmodders/docker-imagemagick'

mapfile -t LATEST_VERSIONS_KEYS < <(jq -r '.latest | keys[]' <<< "$JSON")
# shellcheck disable=SC2207
IFS=$'\n' LATEST_VERSIONS_KEYS=($(sort -rV <<< "${LATEST_VERSIONS_KEYS[*]}")); unset IFS

mapfile -t LEGACY_VERSIONS_KEYS < <(jq -r '.legacy | keys[]' <<< "$JSON")
# shellcheck disable=SC2207
IFS=$'\n' LEGACY_VERSIONS_KEYS=($(sort -rV <<< "${LEGACY_VERSIONS_KEYS[*]}")); unset IFS

readonly BASE_DIR
readonly COMMIT_ID
readonly DISTS
readonly JSON
readonly LATEST_VERSIONS_KEYS
readonly LEGACY_VERSIONS_KEYS
readonly REPOSITORY

function print_url() {
  local tags="$1"
  local commit="$2"
  local directory="$3"
  local url="[$tags]($REPOSITORY/blob/$commit/$directory/Dockerfile)"
  echo "- $url"
}

cd "$BASE_DIR" || exit 1

printf "## Supported tags and respective \`Dockerfile\` links\n\n"

# reference: 7.1.1-30-alpine, 7.1.1-30, alpine, latest
for key in "${LATEST_VERSIONS_KEYS[@]}"; do
  for dist in "${DISTS[@]}"; do
    version="$(jq -r ".latest | .[$key] | .version" <<< "$JSON")"
    latest="$(jq -r ".latest | .[$key] | .latest" <<< "$JSON")"

    tag_dist="$dist"
    tag_full="$version-$dist"
    tag_version="$version"

    tags=''
    if [ "$dist" == 'alpine' ]; then
      tags="\`$tag_full\`, \`$tag_version\`, \`$tag_dist\`"
      if [ "$latest" == 'true' ]; then
        tags="$tags, \`latest\`"
      fi
    else
      tags="\`$tag_full\`, \`$tag_dist\`"
    fi

    print_url "$tags" "$COMMIT_ID" "latest/$dist"
  done
done

# reference: legacy-6.9.13-9-alpine, legacy-6.9.13-9, legacy-alpine, legacy-latest, legacy
for key in "${LEGACY_VERSIONS_KEYS[@]}"; do
  for dist in "${DISTS[@]}"; do
    version="$(jq -r ".legacy | .[$key] | .version" <<< "$JSON")"
    latest="$(jq -r ".legacy | .[$key] | .latest" <<< "$JSON")"

    tag_dist="legacy-$dist"
    tag_full="legacy-$version-$dist"
    tag_version="legacy-$version"

    tags=''
    if [ "$dist" == 'alpine' ]; then
      tags="\`$tag_full\`, \`$tag_version\`, \`$tag_dist\`"
      if [ "$latest" == 'true' ]; then
        tags="$tags, \`legacy-latest\`, \`legacy\`"
      fi
    else
      tags="\`$tag_full\`, \`$tag_dist\`"
    fi

    print_url "$tags" "$COMMIT_ID" "legacy/$dist"
  done
done
