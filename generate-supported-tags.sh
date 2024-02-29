#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMIT_ID=$(git rev-parse --verify HEAD)
DISTS=('alpine' 'debian')
JSON="$(cat ./versions.json)"
REPOSITORY='https://github.com/dstmodders/docker-imagemagick'
VERSIONS_KEYS=()

mapfile -t VERSIONS_KEYS < <(jq -r 'keys[]' <<< "$JSON")
# shellcheck disable=SC2207
IFS=$'\n' VERSIONS_KEYS=($(sort -rV <<< "${VERSIONS_KEYS[*]}")); unset IFS

readonly BASE_DIR
readonly COMMIT_ID
readonly DISTS
readonly JSON
readonly REPOSITORY
readonly VERSIONS_KEYS

function print_url() {
  local tags="$1"
  local commit="$2"
  local directory="$3"
  local url="[$tags]($REPOSITORY/blob/$commit/$directory/Dockerfile)"
  echo "- $url"
}

cd "$BASE_DIR" || exit 1

printf "## Supported tags and respective \`Dockerfile\` links\n\n"

# reference:
#   7.1.1-29-alpine, 7.1.1-29, alpine, latest
#   legacy-6.9.13-7-alpine, legacy-6.9.13-7, legacy-alpine, legacy-latest, legacy
for key in "${VERSIONS_KEYS[@]}"; do
  for dist in "${DISTS[@]}"; do
    version=$(jq -r ".[$key] | .version" <<< "$JSON")
    latest=$(jq -r ".[$key].latest" <<< "$JSON")
    legacy=$(jq -r ".[$key].legacy" <<< "$JSON")

    tag_dist="$dist"
    tag_full="$version-$dist"
    tag_version="$version"

    if [ "$legacy" == 'true' ]; then
      tag_dist="legacy-$tag_dist"
      tag_full="legacy-$tag_full"
      tag_version="legacy-$tag_version"
    fi

    tags=''
    if [ "$dist" == 'alpine' ]; then
      tags="\`$tag_full\`, \`$tag_version\`, \`$tag_dist\`"
      if [ "$latest" == 'true' ]; then
        if [ "$legacy" == 'true' ]; then
          tags="$tags, \`legacy-latest\`, \`legacy\`"
        else
          tags="$tags, \`latest\`"
        fi
      fi
    else
      tags="\`$tag_full\`, \`$tag_dist\`"
    fi

    if [ "$legacy" == 'true' ]; then
      print_url "$tags" "$COMMIT_ID" "legacy/$dist"
    else
      print_url "$tags" "$COMMIT_ID" "latest/$dist"
    fi
  done
done
