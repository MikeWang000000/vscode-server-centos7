#!/bin/bash
set -xeu
cd "$(dirname "$0")"

: "${BUILD_TRIPLET:="$(uname -m)-redhat-linux"}"
: "${TARGET_TRIPLET:="$(uname -m)-linux-gnu"}"
: "${BUILDDIR:="$(realpath ../builddir)"}"

DEPSDIR="$(realpath ../deps)"
PATCHDIR="$(realpath ../patches)"
PREFIX="$BUILDDIR/toolchain"
KERNEL_ARCH="${TARGET_TRIPLET%%-*}"
if [ "$KERNEL_ARCH" = "x86_86" ] || [ "$KERNEL_ARCH" = i*68 ]; then
    KERNEL_ARCH="x86"
elif [ "$KERNEL_ARCH" = "aarch64" ]; then
    KERNEL_ARCH="arm64"
fi


# ====================
# Unarchive sources
for depname in linux binutils glibc gcc; do
    mkdir -p "$BUILDDIR/$depname"
    if [ -e "$DEPSDIR/$depname-src.tar.xz" ]; then
        tar xf "$DEPSDIR/$depname-src.tar.xz" --strip-components 1 -C "$BUILDDIR/$depname"
    else
        tar xf "$DEPSDIR/$depname-src.tar.gz" --strip-components 1 -C "$BUILDDIR/$depname"
    fi
done

for depname in gmp mpfr mpc; do
    mkdir -p "$BUILDDIR/gcc/$depname"
    if [ -e "$DEPSDIR/$depname-src.tar.xz" ]; then
        tar xf "$DEPSDIR/$depname-src.tar.xz" --strip-components 1 -C "$BUILDDIR/gcc/$depname"
    else
        tar xf "$DEPSDIR/$depname-src.tar.gz" --strip-components 1 -C "$BUILDDIR/gcc/$depname"
    fi
done


# ====================
# Linux kernel headers
cd "$BUILDDIR/linux"

make ARCH="$KERNEL_ARCH" defconfig
make ARCH="$KERNEL_ARCH" INSTALL_HDR_PATH="$PREFIX/$TARGET_TRIPLET" headers_install


# ====================
# Binutils
cd "$BUILDDIR/binutils"

mkdir -p builddir
cd builddir
../configure \
    --build="$BUILD_TRIPLET" \
    --host="$BUILD_TRIPLET" \
    --target="$TARGET_TRIPLET" \
    --prefix="$PREFIX/$TARGET_TRIPLET" \
    --program-prefix=""

make -j$(nproc)
make install


# ====================
# GCC (compiler)
cd "$BUILDDIR/gcc"

mkdir -p builddir
cd builddir

../configure \
    --build="$BUILD_TRIPLET" \
    --host="$BUILD_TRIPLET" \
    --target="$TARGET_TRIPLET" \
    --prefix="$PREFIX" \
    --enable-languages=c,c++ \
    --disable-libatomic \
    --disable-multilib \
    --with-newlib

make -j$(nproc) all-gcc
make install-gcc


# ====================
# GLIBC (headers)
cd "$BUILDDIR/glibc"

patch -p1 < "$PATCHDIR/glibc.patch"
patch -p1 < "$PATCHDIR/glibc-fix.patch"

mkdir -p builddir
cd builddir

../configure \
    CC="$PREFIX/bin/$TARGET_TRIPLET-gcc" \
    CXX="$PREFIX/bin/$TARGET_TRIPLET-g++" \
    --build="$BUILD_TRIPLET" \
    --host="$TARGET_TRIPLET" \
    --prefix="$PREFIX/$TARGET_TRIPLET" \
    --enable-kernel=3.10.0 \
    --enable-static-nss \
    --disable-nscd \
    --without-selinux

make install-bootstrap-headers=yes install-headers

cd "$PREFIX/$TARGET_TRIPLET"
mkdir -p include/gnu lib
touch include/gnu/stubs.h lib/libc.so lib/crt1.o lib/crti.o lib/crtn.o


# ====================
# GCC (libgcc)
cd "$BUILDDIR"/gcc/builddir

make -j$(nproc) all-target-libgcc
make install-target-libgcc


# ====================
# GLIBC (final)
cd "$BUILDDIR"/glibc/builddir

make -j$(nproc)
make install


# ====================
# GCC (final)
cd "$BUILDDIR"/gcc/builddir

make distclean
../configure \
    --build="$BUILD_TRIPLET" \
    --host="$BUILD_TRIPLET" \
    --target="$TARGET_TRIPLET" \
    --prefix="$PREFIX" \
    --includedir="$PREFIX/$TARGET_TRIPLET/include" \
    --enable-languages=c,c++ \
    --disable-multilib

make -j$(nproc)
make install
