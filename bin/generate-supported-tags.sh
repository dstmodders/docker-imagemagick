#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMIT_ID="$(git rev-parse --verify HEAD)"
DISTS=('alpine' 'debian')
JSON="$(cat ./versions.json)"
LATEST_VERSIONS_KEYS=()
LEGACY_VERSIONS_KEYS=()
REPOSITORY='https://github.com/dstmodders/docker-imagemagick'

extract_and_sort_keys() {
  local key_path="$1"
  jq -r "$key_path | keys[]" <<< "$JSON" | sort -rV
}

mapfile -t LATEST_VERSIONS_KEYS < <(extract_and_sort_keys '.latest')
mapfile -t LEGACY_VERSIONS_KEYS < <(extract_and_sort_keys '.legacy')

readonly BASE_DIR
readonly COMMIT_ID
readonly DISTS
readonly JSON
readonly LATEST_VERSIONS_KEYS
readonly LEGACY_VERSIONS_KEYS
readonly REPOSITORY

print_url() {
  local tags="$1"
  local commit="$2"
  local directory="$3"
  local url="[$tags]($REPOSITORY/blob/$commit/$directory/Dockerfile)"
  echo "- $url"
}

cd "$BASE_DIR" || exit 1

printf "## Supported tags and respective \`Dockerfile\` links\n\n"

# reference: 7.1.1-38-alpine, 7.1.1-38, alpine, latest
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

# reference: legacy-6.9.13-16-alpine, legacy-6.9.13-16, legacy-alpine, legacy-latest, legacy
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
