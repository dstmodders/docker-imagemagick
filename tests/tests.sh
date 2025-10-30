#!/usr/bin/env sh

# define constants
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_RECT_SIZE='50'

readonly BASE_DIR
readonly IMAGE_RECT_SIZE

create() {
  if [ "$(printf '%s' "$IMAGEMAGICK_VERSION" | cut -c 1)" -eq '6' ]; then
    # shellcheck disable=SC2068
    convert $@
  else
    # shellcheck disable=SC2068
    magick $@
  fi
}

create_rect() {
  # shellcheck disable=SC2068
  create -size "${IMAGE_RECT_SIZE}x${IMAGE_RECT_SIZE}" xc:white $@
}

create_white() {
  ext="$1"

  echo "Generating white.$ext..."
  create_rect "white.$ext"
}

convert_to_jpg() {
  file="$1"
  base="${file%.*}"

  create "$file" "$base.jpg"
}

# PerlImagick
cd "$BASE_DIR/perlmagick/" || exit 1

./demo.pl

# plain white squares
mkdir -p "$BASE_DIR/result/"
cd "$BASE_DIR/result/" || exit 1

echo '---'
create_white gif
create_white jpg
create_white pam
create_white pdf
create_white png
create_white tiff
create_white webp

#create_white avif
#create_white heic
#create_white jxl
#create_white jxr

echo 'Generating text.png...'
create_rect -font DejaVu-Sans -gravity Center -pointsize 16 -annotate 0 'TEXT' text.png

if [ -f "$BASE_DIR/perlmagick/demo.pam" ]; then
  echo '---'
  echo 'Moving PerlMagick demo.pam...'
  cp "$BASE_DIR/perlmagick/demo.pam" "$BASE_DIR/result/demo.pam"
  echo 'Generating PerlMagick demo.jpg...'
  convert_to_jpg "$BASE_DIR/result/demo.pam"
fi
