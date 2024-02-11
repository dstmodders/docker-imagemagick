#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMIT_ID=$(git rev-parse --verify HEAD)
DISTS=('alpine' 'debian')
VERSIONS=()

mapfile -t VERSIONS < <(jq -r 'keys[]' ./versions.json)
IFS=$'\n' VERSIONS=($(sort -rV <<< "${VERSIONS[*]}")); unset IFS

readonly BASE_DIR
readonly COMMIT_ID
readonly DISTS
readonly VERSIONS

# https://stackoverflow.com/a/17841619
function join_by {
  local d="${1-}"
  local f="${2-}"
  if shift 2; then
    printf %s "$f" "${@/#/$d}";
  fi
}

function jq_value {
  local from="$1"
  local key="$2"
  local name="$3"
  jq -r ".[${key}] | .${name}" "${from}"
}

function print_url() {
  local tags="$1"
  local commit="$2"
  local dist="$3"
  local legacy="$4"

  local url="[$tags](https://github.com/dstmodders/docker-imagemagick/blob/${commit}/latest/${dist}/Dockerfile)"
  if [ "${legacy}" == 'true' ]; then
    url="[$tags](https://github.com/dstmodders/docker-imagemagick/blob/${commit}/legacy/${dist}/Dockerfile)"
  fi

  echo "- ${url}"
}

cd "${BASE_DIR}" || exit 1

printf "## Supported tags and respective \`Dockerfile\` links\n\n"

for v in "${VERSIONS[@]}"; do
  for dist in "${DISTS[@]}"; do
    commit="${COMMIT_ID}"
    version=$(jq -r ".[${v}] | .version" ./versions.json)
    latest=$(jq_value ./versions.json "${v}" 'latest')
    legacy=$(jq_value ./versions.json "${v}" 'legacy')

    tag_dist="${dist}"
    tag_full="${version}-${dist}"
    tag_version="${version}"

    if [ "${legacy}" == 'true' ]; then
      tag_dist="legacy-${tag_dist}"
      tag_full="legacy-${tag_full}"
      tag_version="legacy-${tag_version}"
    fi

    tags=''
    if [ "${dist}" == 'alpine' ]; then
      tags="\`${tag_full}\`, \`${tag_version}\`, \`${tag_dist}\`"
      if [ "${latest}" == 'true' ]; then
        if [ "${legacy}" == 'true' ]; then
          tags="${tags}, \`legacy-latest\`, \`legacy\`"
        else
          tags="${tags}, \`latest\`"
        fi
      fi
    else
      tags="\`${tag_full}\`, \`${tag_dist}\`"
    fi

    print_url "${tags}" "${commit}" "${dist}" "${legacy}"
  done
done
