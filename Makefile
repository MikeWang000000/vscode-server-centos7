PROD_VER = $(shell cat version.txt)
BUILD_TRIPLET = $(shell uname -m)-redhat-linux
ARCH := $(shell uname -m)

ifeq ($(ARCH), x86_64)
	override ARCH = x64
	TARGET_TRIPLET = x86_64-linux-gnu
else ifeq ($(ARCH), x64)
	TARGET_TRIPLET = x86_64-linux-gnu
else ifeq ($(ARCH), aarch64)
	override ARCH = arm64
	TARGET_TRIPLET = aarch64-linux-gnu
else ifeq ($(ARCH), arm64)
	TARGET_TRIPLET = aarch64-linux-gnu
else ifeq ($(ARCH), arm)
	override ARCH = armhf
	TARGET_TRIPLET = arm-none-linux-gnueabi
else ifeq ($(ARCH), armhf)
	TARGET_TRIPLET = arm-none-linux-gnueabi
endif

SRCDIR = src
DEPSDIR = deps
DISTDIR = dist
BUILDDIR = builddir.$(ARCH)
LIBDIR = $(BUILDDIR)/lib

VSCODE_SERVER = vscode-server
VSCODE_SERVER_TAR = $(DISTDIR)/$(VSCODE_SERVER)_$(PROD_VER)_$(ARCH).tar.gz
VSCODE_SERVER_DIR = $(BUILDDIR)/$(VSCODE_SERVER)

SRV_TAR = $(DEPSDIR)/vscode-srv-$(ARCH).tar.gz
CLI_TAR = $(DEPSDIR)/vscode-cli-$(ARCH).tar.gz

TOOLCHAIN_DEPS = $(DEPSDIR)/linux-src.tar.xz $(DEPSDIR)/binutils-src.tar.xz $(DEPSDIR)/glibc-src.tar.xz $(DEPSDIR)/gcc-src.tar.xz $(DEPSDIR)/gmp-src.tar.xz $(DEPSDIR)/mpfr-src.tar.xz $(DEPSDIR)/mpc-src.tar.gz
VSCODE_DEPS = $(SRV_TAR) $(CLI_TAR)

LIBFASTJSON = $(LIBDIR)/libfastjson.a
LIBPATCHELF = $(LIBDIR)/libpatchelf.a

HEADERS = $(wildcard libfastjson/*.h) $(wildcard libfastjson/*.h)
CODEBIN = $(BUILDDIR)/code
CODESRC = $(SRCDIR)/code.c

TOOLCHAIN_DIR = $(BUILDDIR)/toolchain
CROSS_PREFIX = $(TOOLCHAIN_DIR)/bin/$(TARGET_TRIPLET)-
CROSS_CC = $(CROSS_PREFIX)gcc
CROSS_CXX = $(CROSS_PREFIX)g++
CROSS_STRIP = $(TOOLCHAIN_DIR)/$(TARGET_TRIPLET)/bin/strip
CROSS_LIBDIR = $(TOOLCHAIN_DIR)/$(TARGET_TRIPLET)/lib
CROSS_LIB64DIR = $(TOOLCHAIN_DIR)/$(TARGET_TRIPLET)/lib64
TOOLCHAIN = $(CROSS_CC) $(CROSS_CXX) $(CROSS_STRIP)

INCLUDES = -I.
CFLAGS += -static -Wall -Wextra $(INCLUDES)
LDFLAGS += -lstdc++ -lm

all: $(VSCODE_SERVER_TAR)

code: $(CODEBIN)

toolchain: $(TOOLCHAIN)

$(VSCODE_DEPS) $(TOOLCHAIN_DEPS):
	env TARGET_TRIPLET='$(TARGET_TRIPLET)' bash scripts/download-deps.sh

$(CROSS_CC) $(CROSS_CXX) $(CROSS_STRIP): $(TOOLCHAIN_DEPS)
	env BUILD_TRIPLET='$(BUILD_TRIPLET)' TARGET_TRIPLET='$(TARGET_TRIPLET)' BUILDDIR='$(shell realpath $(BUILDDIR))' bash scripts/build-gcc-toolchain.sh

$(LIBFASTJSON): $(TOOLCHAIN)
	cd libfastjson && ./autogen.sh CC='$(shell realpath $(CROSS_CC))' --prefix='$(shell realpath $(BUILDDIR))' --build='$(BUILD_TRIPLET)' --host='$(TARGET_TRIPLET)' && $(MAKE) clean && $(MAKE) install

$(LIBPATCHELF): $(TOOLCHAIN)
	cd libpatchelf && $(MAKE) clean && $(MAKE) LIBDIR='$(shell realpath $(LIBDIR))' CROSS_PREFIX='$(shell realpath $(CROSS_PREFIX))'

$(CODEBIN): $(TOOLCHAIN) $(CODESRC) $(HEADERS) $(LIBFASTJSON) $(LIBPATCHELF)
	$(CROSS_CC) $(CFLAGS) -o $(CODEBIN) $(CODESRC) $(LIBFASTJSON) $(LIBPATCHELF) $(LDFLAGS)
	$(CROSS_STRIP) --strip-all -R .comment $(CODEBIN)

$(VSCODE_SERVER_TAR): $(VSCODE_DEPS) $(TOOLCHAIN) $(CLI_TAR) $(SRV_TAR) $(CODEBIN)
	rm -rf $(VSCODE_SERVER_DIR) $(BUILDDIR)/cli $(BUILDDIR)/srv
	mkdir $(VSCODE_SERVER_DIR) $(BUILDDIR)/cli $(BUILDDIR)/srv
	tar xf $(CLI_TAR) -C $(BUILDDIR)/cli code
	cp -a $(BUILDDIR)/cli/code "$(VSCODE_SERVER_DIR)/code-$$(cat $(DEPSDIR)/vscode-version.txt)-cli"
	cp -a $(CODEBIN) "$(VSCODE_SERVER_DIR)/code-$$(cat $(DEPSDIR)/vscode-version.txt)"
	ln -s "code-$$(cat $(DEPSDIR)/vscode-version.txt)" $(VSCODE_SERVER_DIR)/code-latest
	tar xf $(SRV_TAR) -C $(BUILDDIR)/srv --strip-components=1
	mkdir -p "$(VSCODE_SERVER_DIR)/cli/servers/Stable-$$(cat $(DEPSDIR)/vscode-version.txt)"
	cp -a $(BUILDDIR)/srv "$(VSCODE_SERVER_DIR)/cli/servers/Stable-$$(cat $(DEPSDIR)/vscode-version.txt)/server"
	mkdir -p "$(VSCODE_SERVER_DIR)/bin"
	ln -s "../cli/servers/Stable-$$(cat $(DEPSDIR)/vscode-version.txt)/server" "$(VSCODE_SERVER_DIR)/bin/$$(cat $(DEPSDIR)/vscode-version.txt)"
	mkdir -p $(VSCODE_SERVER_DIR)/gnu
	if [ -e '$(CROSS_LIB64DIR)' ]; then cp -a '$(CROSS_LIB64DIR)'/. $(VSCODE_SERVER_DIR)/gnu; fi
	cp -a '$(CROSS_LIBDIR)'/. $(VSCODE_SERVER_DIR)/gnu
	find $(VSCODE_SERVER_DIR)/gnu -regex '.*\.\(a\|la\|o\|py\|spec\)' -delete
	mkdir -p $(DISTDIR)
	cd $(BUILDDIR) && tar --owner=0 --group=0 --no-same-owner --no-same-permissions -czf ../$(VSCODE_SERVER_TAR) $(VSCODE_SERVER)

clean_libfastjson:
	cd libfastjson && test -f Makefile && $(MAKE) distclean || true
	cd libfastjson && rm -rf .deps INSTALL Makefile.in aclocal.m4 autom4te.cache compile config.guess config.h.in config.sub configure depcomp install-sh ltmain.sh m4/libtool.m4 m4/ltoptions.m4 m4/ltsugar.m4 m4/ltversion.m4 m4/lt~obsolete.m4 missing test-driver tests/.deps tests/Makefile.in

clean_libpatchelf:
	cd libpatchelf && $(MAKE) clean || true

clean: clean_libfastjson clean_libpatchelf	
	$(RM) -r $(BUILDDIR) $(DISTDIR)

clean_deps:
	$(RM) -r $(BUILDDIR) $(DEPSDIR)

clean_all: clean clean_deps

.PHONY: all code clean clean_libfastjson clean_libpatchelf
