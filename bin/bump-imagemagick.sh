#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKERHUB_START_LINE=10
JSON="$(cat "$BASE_DIR/../versions.json")"
PROGRAM="$(basename "$0")"
README_START_LINE=17

readonly BASE_DIR
readonly DOCKERHUB_START_LINE
readonly JSON
readonly PROGRAM
readonly README_START_LINE

usage() {
  echo -e "Bump the latest or legacy ImageMagick version.

    Usage:
      $PROGRAM [flags] [latest|legacy] [version]

    Flags:
      -c, --commit   commit changes
      -h, --help     help for $PROGRAM" | sed -E 's/^ {4}//'
}

print_bold() {
  local value="$1"
  if [ "$DISABLE_COLORS" = '1' ] || ! [ -t 0 ]; then
    printf '%s' "$value"
  else
    printf "$(tput bold)%s$(tput sgr0)" "$value"
  fi
}

print_bold_red() {
  local value="$1"
  if [ "$DISABLE_COLORS" = '1' ] || ! [ -t 0 ]; then
    printf '%s' "$value"
  else
    printf "$(tput bold)$(tput setaf 1)%s$(tput sgr0)" "$value"
  fi
}

print_error() {
  print_bold_red "error: $1"
  echo ''
}

summary() {
  local name="$1"
  local old_version="$2"
  local new_version="$3"
  local files=(
    'DOCKERHUB.md'
    'README.md'
    'bin/generate-supported-tags.sh'
    "$name/alpine/Dockerfile"
    "$name/debian/Dockerfile"
    'versions.json'
  )

  print_bold '[FILES]'
  printf '\n\n'
  for file in "${files[@]}"; do
    echo "$file"
  done

  printf '\n'
  print_bold '[VERSION]'
  printf '\n\n'

  echo "Current: $old_version"
  echo "New: $new_version"
}

replace() {
  local name="$1"
  local old_version="$2"
  local new_version="$3"

  printf 'Replacing...'
  sed -i "$DOCKERHUB_START_LINE,\$s/\`$old_version\`/\`$new_version\`/g" ./DOCKERHUB.md
  sed -i "$README_START_LINE,\$s/\`$old_version\`/\`$new_version\`/g" ./README.md
  sed -i "s/\"$old_version\"/\"$new_version\"/" ./versions.json
  sed -i "/^# reference:/s/$old_version/$new_version/g" ./bin/generate-supported-tags.sh
  sed -i "s/^ARG IMAGEMAGICK_VERSION=\"$old_version\"$/ARG IMAGEMAGICK_VERSION=\"$new_version\"/" "./$name/alpine/Dockerfile"
  sed -i "s/^ARG IMAGEMAGICK_VERSION=\"$old_version\"$/ARG IMAGEMAGICK_VERSION=\"$new_version\"/" "./$name/debian/Dockerfile"
  printf ' Done\n'
}

cd "$BASE_DIR/.." || exit 1

name=''
commit=0

while [ $# -gt 0 ]; do
  key="$1"
  value="$2"

  case "$key" in
    latest|legacy)
      name="$key"
      shift 1
      ;;
    -c|--commit)
      commit=1
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      print_error 'unrecognized flag'
      exit 1
      ;;
    *)
      new_version="$key"
      shift 1
      ;;
  esac
done

if [ -z "$name" ]; then
  echo 'Choose bump option:'
  options=('latest' 'legacy')
  select opt in "${options[@]}"; do
    case $opt in
      latest) name='latest'; break ;;
      legacy) name='legacy'; break ;;
      *) print_error 'unrecognized option (choose number 1 or 2)' ;;
    esac
  done
fi

if [ -n "$name" ]; then
  old_version="$(jq -r ".$name.[-1].version" <<< "$JSON")"

  if [ -z "$new_version" ]; then
    echo "Current version: $old_version"
    read -rp "Enter new $name version: " new_version
    echo '---'
  fi

  summary "$name" "$old_version" "$new_version"
  echo '---'
  replace "$name" "$old_version" "$new_version"

  if [ "$commit" -eq 1 ]; then
  printf 'Committing...'
    git add \
      DOCKERHUB.md \
      README.md \
      bin/generate-supported-tags.sh \
      "$name/alpine/Dockerfile" \
      "$name/debian/Dockerfile" \
      versions.json
    if [ -n "$(git diff --cached --name-only)" ]; then
      git commit -m "Bump ImageMagick from $old_version to $new_version"
      printf ' Done\n'
    else
      printf ' Skipped\n'
    fi
  fi

  exit 0
fi