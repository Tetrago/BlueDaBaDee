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

identifyDistro() {
  id=$(
    . /etc/os-release
    echo "$ID"
  )

  if [ $? -eq 0 ] && [ ! -z "$id" ]; then
    echo "$id"
    return 0
  else
    return 1
  fi
}

# $1: Kernel source directory
configureKernel() {
  source=$1

  case "$(identifyDistro)" in
  *debian*)
    cp /boot/config-$(uname -r) "$1/.config"
    echo "Importing kernel parameters..."
    make -C "$1" olddefconfig
    ;;
  *)
    printf "${RED}Warning:${CLEAR} Unable to determine installed distribution\n" >&2
    echo "Defaulting kernel parameters..."
    make -C "$1" defconfig
    ;;
  esac
}

# $1: Kernel source directory
buildKernel() {
  make -C "$1" -j "$(nproc)"
}

installBuildDependencies() {
  case "$(identifyDistro)" in
  *debian*)
    echo "Installing build dependencies..."
    sudo apt-get update
    sudo apt-get install -y build-essential bison flex libssl-dev libelf-dev bc python3 dwarves
    return 0
    ;;
  *)
    printf "${RED}Warning:${CLEAR} Unable to determine installed distribution. Cannot install build dependencies\n" >&2
    echo "Checking for required dependencies..."
    valid=0

    for x in gcc make bc flex bison ld objcopy objdump ar readelf python3 pahole; do
      if ! command -v "$x" >/dev/null 2>&1; then
        printf "${RED}Error:${CLEAR} Missing build dependency: $x\n" >&2
        valid=1
      fi
    done

    if [ "$valid" -ne 0 ]; then
      printf "${RED}Error:${CLEAR} Missing required build dependencies.\n" >&2
      return 1
    else
      printf "${RED}Warning:${CLEAR} Required build dependencies found, but required libraries may still be missing\n" >&2
    fi
    ;;
  esac
}

installBuildDependencies
fetchKernel $1 kernel
configureKernel kernel
buildKernel kernel
