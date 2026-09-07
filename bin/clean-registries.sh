#!/usr/bin/env bash
#
# Clean up Docker registries keeping the latest versions based on versions.json
# and up to 3 of the most recent ones.
#
# Usage:
#   clean-registries.sh [flags] <registry>
#
# Examples:
#   clean-registries.sh -d ghcr
#   clean-registries.sh -y dockerhub
#
# Arguments:
#   <registry>           Registry: "ghcr" or "dockerhub"
#
# Flags:
#   -d, --dry-run        Only check and don't delete any tags
#   -h, --help           Show this help message
#   -y, --yes            Confirm deletions without a prompt
#
# Environment Variables:
#   DOCKERHUB_TOKEN      Docker Hub personal access token with delete scope
#                        (default "")
#
#   DOCKERHUB_USERNAME   Docker Hub username
#                        (default "")
#
#   GHCR_TOKEN           GHCR token with package:delete scope
#                        (default "")
#
#   NO_COLOR             Set to 1 to disable terminal colors
#                        (see no-color.org, default "0")
#
#   REPOSITORY           Registry repository name
#                        (default "dstmodders/imagemagick")
#
set -euo pipefail

# define constants
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
JSON="$(cat "${BASE_DIR}/../versions.json")"

readonly BASE_DIR
readonly JSON

# shellcheck disable=SC1091
source "${BASE_DIR}/common.sh"

# define defaults for environment variables
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:-}"
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
GHCR_TOKEN="${GHCR_TOKEN:-}"
NO_COLOR="${NO_COLOR:-0}"
REPOSITORY="${REPOSITORY:-dstmodders/imagemagick}"

# define arguments
ARG_REGISTRY=''

# define flags
FLAG_DRY_RUN=0
FLAG_YES=0

# define other global variables
BLUE_TAGS=()
EXTRA_TAGS=()
KEEP_TAGS=()
REGISTRY_TAGS=()

generate_keep_tags_for_family() {
  local latest
  local version

  local family="$1"
  local dist_tags=''
  local prefix=''

  for minor_key in $(jq -r ".${family} | keys[]" <<< "${JSON}" | sort -rV); do
    version="$(jq -r ".${family} | .[${minor_key}] | .version" <<< "${JSON}")"
    latest="$(jq -r ".${family} | .[${minor_key}] | .latest // false" <<< "${JSON}")"

    if [ "${family}" = 'legacy' ]; then
      prefix='legacy-'
    fi

    BLUE_TAGS+=("${prefix}${version}-alpine")
    BLUE_TAGS+=("${prefix}${version}-debian")
    BLUE_TAGS+=("${prefix}${version}")
    KEEP_TAGS+=("${prefix}${version}-alpine")
    KEEP_TAGS+=("${prefix}${version}-debian")
    KEEP_TAGS+=("${prefix}${version}")

    if [ "${latest}" = 'true' ]; then
      if [ "${family}" = 'legacy' ]; then
        dist_tags=('legacy-alpine' 'legacy-debian' 'legacy-latest' 'legacy')
      else
        dist_tags=('alpine' 'debian' 'latest')
      fi
      for tag in "${dist_tags[@]}"; do
        BLUE_TAGS+=("${tag}")
        KEEP_TAGS+=("${tag}")
      done
    fi
  done
}

tag_is_blue() {
  local tag="$1"

  local blue

  for blue in "${BLUE_TAGS[@]}"; do
    if [ "${blue}" = "${tag}" ]; then
      return 0
    fi
  done

  return 1
}

compute_extra_tags() {
  local candidate
  local candidates_str
  local family
  local minor
  local tag
  local version

  local -A seen=()
  local candidates=()
  local prefix=''

  for family in latest legacy; do
    prefix=''
    if [ "${family}" = 'legacy' ]; then
      prefix='legacy-'
    fi

    for version in $(jq -r ".${family}[].version" <<< "${JSON}" | sort -u); do
      minor="${version%-*}"
      candidates=()
      seen=()

      for tag in "${REGISTRY_TAGS[@]}"; do
        candidate="${tag#"${prefix}"}"
        candidate="${candidate%-alpine}"
        candidate="${candidate%-debian}"
        if [[ "${candidate}" == "${minor}-"* ]] && [ -z "${seen[${candidate}]:-}" ]; then
          seen["${candidate}"]=1
          candidates+=("${candidate}")
        fi
      done

      # keep up to 3 total per minor (including the whitelisted latest)
      candidates_str="$(printf '%s\n' "${candidates[@]}" | sort -Vu | tail -n 3)"
      while IFS= read -r candidate; do
        if tag_is_blue "${prefix}${candidate}"; then
          continue
        fi
        EXTRA_TAGS+=("${prefix}${candidate}")
        EXTRA_TAGS+=("${prefix}${candidate}-alpine")
        EXTRA_TAGS+=("${prefix}${candidate}-debian")
      done <<< "${candidates_str}"
    done
  done
}

tag_is_kept() {
  local kept

  local tag="$1"

  if tag_is_blue "${tag}"; then
    return 0
  fi

  for kept in "${EXTRA_TAGS[@]}"; do
    if [ "${kept}" = "${tag}" ]; then
      return 0
    fi
  done

  return 1
}

print_totals() {
  local name="$1"
  local total="$2"

  local blue_tags=()
  local extra_tags=()
  local sorted=()
  local tag=''
  local to_delete=()

  for tag in "${REGISTRY_TAGS[@]}"; do
    if tag_is_blue "${tag}"; then
      blue_tags+=("${tag}")
    elif tag_is_kept "${tag}"; then
      extra_tags+=("${tag}")
    else
      to_delete+=("${tag}")
    fi
  done

  print_step_dotted 'Printing tags'
  printf '\n'
  print_separator
  printf 'Total: '
  print_bold_color 7 "${total}"
  printf ' | '
  printf 'Keep: '
  print_bold_color 4 "$((${#blue_tags[@]} + ${#extra_tags[@]}))"
  printf ' | '
  printf 'Delete: '
  print_bold_color 1 "${#to_delete[@]}"
  printf '\n\n'

  print_bold_color 7 'Tags to keep (from versions.json) / '
  print_bold_color 4 "${#blue_tags[@]} tags"
  printf ':\n\n'
  if [ "${#blue_tags[@]}" -gt 0 ]; then
    mapfile -t sorted <<< "$(printf '%s\n' "${blue_tags[@]}" | sort)"
    for tag in "${sorted[@]}"; do
      printf ''
      print_bold_color 4 "${tag}"
      printf '\n'
    done
  else
    print_bold_color 0 'No tags found'
    printf '\n'
  fi
  printf '\n'

  print_bold_color 7 'Tags to keep (most recent) / '
  print_bold_color 4 "${#extra_tags[@]} tags"
  printf ':\n\n'
  if [ "${#extra_tags[@]}" -gt 0 ]; then
    mapfile -t sorted <<< "$(printf '%s\n' "${extra_tags[@]}" | sort)"
    for tag in "${sorted[@]}"; do
      printf ''
      print_bold_color 4 "${tag}"
      printf '\n'
    done
  else
    print_bold_color 0 'No tags found'
    printf '\n'
  fi
  printf '\n'

  print_bold_color 7 'Tags to delete / '
  print_bold_color 1 "${#to_delete[@]} tags"
  printf ':\n\n'
  if [ "${#to_delete[@]}" -gt 0 ]; then
    mapfile -t sorted <<< "$(printf '%s\n' "${to_delete[@]}" | sort)"
    for tag in "${sorted[@]}"; do
      print_bold_color 1 "${tag}"
      printf '\n'
    done
  else
    print_bold_color 0 'No tags found'
    printf '\n'
  fi
}

ghcr_token() {
  local scope="${1:-repository:${REPOSITORY}:pull}"
  curl -s "https://ghcr.io/token?service=ghcr.io&scope=${scope}" | jq -r '.token'
}

ghcr_list_tags() {
  local body
  local headers
  local link_header

  local token="$1"
  local all_tags=()
  local tag=''
  local url="/v2/${REPOSITORY}/tags/list?n=100"

  while [ -n "${url}" ]; do
    headers="$(mktemp)"
    body="$(mktemp)"

    curl -s -D "${headers}" -o "${body}" \
      -H "Authorization: Bearer ${token}" \
      "https://ghcr.io${url}"

    while IFS= read -r tag; do
      all_tags+=("${tag}")
    done < <(jq -r '.tags[]?' < "${body}")

    link_header="$(grep -i '^link:' "${headers}" || true)"
    if [[ "${link_header}" =~ \<([^>]+)\> ]]; then
      url="${BASH_REMATCH[1]}"
    else
      url=''
    fi

    rm -f "${headers}" "${body}"
  done

  printf '%s\n' "${all_tags[@]}"
}

# shellcheck disable=SC2329
ghcr_delete_tag() {
  local digest

  local token="$1"
  local tag="$2"

  digest="$(curl -s -D - -o /dev/null \
    -H "Authorization: Bearer ${token}" \
    -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
    "https://ghcr.io/v2/${REPOSITORY}/manifests/${tag}" \
    | awk 'tolower($1) == "docker-content-digest:" { print $2 }' | tr -d '\r')"

  if [ -z "${digest}" ]; then
    printf '000'
    return 0
  fi

  curl -s -o /dev/null -w '%{http_code}' \
    -X DELETE \
    -H "Authorization: Bearer ${token}" \
    "https://ghcr.io/v2/${REPOSITORY}/manifests/${digest}"
}

dockerhub_token() {
  curl -s -H 'Content-Type: application/json' \
    -X POST -d "{\"username\": \"${DOCKERHUB_USERNAME}\", \"password\": \"${DOCKERHUB_TOKEN}\"}" \
    'https://hub.docker.com/v2/users/login/' | jq -r '.token'
}

dockerhub_list_tags() {
  local token="$1"

  local all_tags=()
  local json=''
  local next="https://hub.docker.com/v2/repositories/${REPOSITORY}/tags/?page_size=100"
  local tag=''

  while [ -n "${next}" ]; do
    json="$(curl -s -H "Authorization: JWT ${token}" "${next}")"
    while IFS= read -r tag; do
      all_tags+=("${tag}")
    done < <(jq -r '.results[].name?' <<< "${json}")

    next="$(jq -r '.next? // empty' <<< "${json}")"
  done

  printf '%s\n' "${all_tags[@]}"
}

# shellcheck disable=SC2329
dockerhub_delete_tag() {
  local token="$1"
  local tag="$2"

  curl -s -o /dev/null -w '%{http_code}' \
    -X DELETE \
    -H "Authorization: JWT ${token}" \
    "https://hub.docker.com/v2/repositories/${REPOSITORY}/tags/${tag}/"
}

run_cleanup() {
  local status

  local name="$1"
  local tags="$2"
  local delete_fn="$3"
  local token="$4"
  local tag=''

  mapfile -t REGISTRY_TAGS <<< "${tags}"
  if [ ${#REGISTRY_TAGS[@]} -eq 0 ] || [ -z "${REGISTRY_TAGS[0]}" ]; then
    print_step_skipped "Skipped (no tags found in ${name})"
    return 0
  fi
  EXTRA_TAGS=()
  compute_extra_tags
  print_totals "${name}" "${#REGISTRY_TAGS[@]}"

  if [ "${FLAG_DRY_RUN}" -eq 1 ]; then
    return 0
  fi

  local to_delete=()
  for tag in "${REGISTRY_TAGS[@]}"; do
    if ! tag_is_kept "${tag}"; then
      to_delete+=("${tag}")
    fi
  done

  print_separator

  if [ "${#to_delete[@]}" -gt 0 ]; then
    print_bold_color 1 'WARNING: you are about to delete tags from the registry'
    printf '\n'
    print_bold_color 1 'Press Ctrl+C to abort. Deleting in 15 seconds...'
    printf '\n'
    print_separator
    sleep 15
  fi

  for tag in "${to_delete[@]}"; do
    print_step_dotted 'Deleting' "${tag}"
    status="$("${delete_fn}" "${token}" "${tag}" || true)"
    if [ "${status}" = '204' ] || [ "${status}" = '202' ] || [ "${status}" = '200' ]; then
      print_step_success
    elif [ "${status}" = '000' ]; then
      print_step_skipped "Skipped (no digest)"
    else
      print_step_skipped "Skipped (HTTP ${status})"
    fi
  done
}

clean_ghcr() {
  local read_token
  local tags

  if [ -z "${GHCR_TOKEN}" ]; then
    die 'GHCR token not set'
  fi

  print_step_dotted 'Computing tags to keep'
  generate_keep_tags_for_family 'latest'
  generate_keep_tags_for_family 'legacy'
  print_step_success

  print_step_dotted 'Fetching tags from GHCR'
  read_token="$(ghcr_token 'repository:'"${REPOSITORY}"':pull')"
  tags="$(ghcr_list_tags "${read_token}")"
  print_step_success

  run_cleanup 'GHCR' "${tags}" ghcr_delete_tag "${GHCR_TOKEN}"
}

clean_dockerhub() {
  local tags
  local token

  if [ -z "${DOCKERHUB_USERNAME}" ] || [ -z "${DOCKERHUB_TOKEN}" ]; then
    die 'Docker Hub credentials not set'
  fi

  print_step_dotted 'Computing tags to keep'
  generate_keep_tags_for_family 'latest'
  generate_keep_tags_for_family 'legacy'
  print_step_success

  print_step_dotted 'Fetching tags from Docker Hub'
  token="$(dockerhub_token)"
  tags="$(dockerhub_list_tags "${token}")"
  print_step_success

  run_cleanup 'Docker Hub' "${tags}" dockerhub_delete_tag "${token}"
}

cd "${BASE_DIR}/.." || exit 1

while [ $# -gt 0 ]; do
  key="$1"
  case "${key}" in
    -d | --dry-run)
      FLAG_DRY_RUN=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -y | --yes)
      FLAG_YES=1
      ;;
    ghcr | dockerhub)
      ARG_REGISTRY="${key}"
      ;;
    *)
      die 'unexpected argument'
      ;;
  esac
  shift 1
done

readonly FLAG_DRY_RUN
readonly FLAG_YES

if [ -z "${ARG_REGISTRY}" ]; then
  die 'missing registry (expected "ghcr" or "dockerhub")'
fi

trap interrupt SIGINT

if [ "${FLAG_YES}" -eq 0 ] && [ "${FLAG_DRY_RUN}" -eq 0 ]; then
  die 'refusing to delete without --yes (or --dry-run)'
fi

case "${ARG_REGISTRY}" in
  ghcr)
    clean_ghcr
    ;;
  dockerhub)
    clean_dockerhub
    ;;
esac

if [ "${FLAG_DRY_RUN}" -eq 1 ]; then
  complete 3 'Dry-run completed'
fi

complete 2 'Cleanup completed'
