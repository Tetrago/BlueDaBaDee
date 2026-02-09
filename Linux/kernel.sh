#!/bin/sh

RED="\033[31;1m"
CLEAR="\033[0m"

# $1: Kernel version delimited with periods. Ex: 5.10.114
# $2: Output directory. Kernel source should be unpacked into said directory with no top-level folders.
fetchKernel() {
  version=$1
  out=$2

  IFS=. read -r major minor patch <<EOF
$version
EOF

  if [ -z "$major" ] || [ -z "$minor" ] || [ -z "$patch" ]; then
    printf "${RED}Error:${CLEAR} Invalid kernel version specified\n" >&2
    return 1
  fi

  if [ "$major" = 1 ] || [ "$major" = 2 ]; then
    url="https://cdn.kernel.org/pub/linux/kernel/v$major.$minor/linux-$version.tar.xz"
  elif [ "$major" = 3 ] && [ "$minor" = 0 ]; then
    url="https://cdn.kernel.org/pub/linux/kernel/v3.0/linux-$version.tar.xz"
  else
    url="https://cdn.kernel.org/pub/linux/kernel/v$major.x/linux-$version.tar.xz"
  fi

  mkdir -p "$out"

  echo "Fetching kernel..."

  if command -v curl >/dev/null 2>&1; then
    curl -fSL -o "$out.tar.xz" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$out.tar.xz" "$url"
  else
    printf "${RED}Error:${CLEAR} curl or wget must be present on system\n" >&2
    return 1
  fi

  echo "Unpacking kernel..."
  tar -xJf "$out.tar.xz" --strip-components=1 -C "$out"
  rm "$out.tar.xz"
}

fetchKernel $@
