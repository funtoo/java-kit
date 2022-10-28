# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit check-reqs eapi8-dosym flag-o-matic java-pkg-2 java-vm-2 multiprocessing toolchain-funcs

# we need latest -ga tag from git, but want to keep build number as well
# as _p component of the gentoo version string.


DESCRIPTION="Open source implementation of the Java programming language"
HOMEPAGE="https://openjdk.java.net"
SRC_URI="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u352-b08/OpenJDK8U-jdk-sources_8u352b08.tar.gz -> OpenJDK8U-jdk-sources_8u352b08.tar.gz"

LICENSE="GPL-2"
KEYWORDS="*"
SLOT="$(ver_cut 1)"
IUSE="alsa debug cups doc examples headless-awt javafx selinux source"

COMMON_DEPEND="
	media-libs/freetype:2=
	media-libs/giflib:0/7
	sys-libs/zlib
"
# Many libs are required to build, but not to run, make is possible to remove
# by listing conditionally in RDEPEND unconditionally in DEPEND
RDEPEND="
	${COMMON_DEPEND}
	>=sys-apps/baselayout-java-0.1.0-r1
	!headless-awt? (
		x11-libs/libX11
		x11-libs/libXext
		x11-libs/libXi
		x11-libs/libXrender
		x11-libs/libXt
		x11-libs/libXtst
	)
	alsa? ( media-libs/alsa-lib )
	cups? ( net-print/cups )
	selinux? ( sec-policy/selinux-java )
"

DEPEND="
	${COMMON_DEPEND}
	app-arch/zip
	media-libs/alsa-lib
	net-print/cups
	virtual/pkgconfig
	x11-base/xorg-proto
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXi
	x11-libs/libXrender
	x11-libs/libXt
	x11-libs/libXtst
	|| (
		dev-java/openjdk-bin:${SLOT}
		dev-java/icedtea-bin:${SLOT}
		dev-java/openjdk:${SLOT}
		dev-java/icedtea:${SLOT}
	)
"

BDEPEND="
	virtual/pkgconfig
"

PDEPEND="javafx? ( dev-java/openjfx:${SLOT} )"

S="${WORKDIR}/jdk8u352-b08-src"

PATCHES=( "${FILESDIR}/openjdk-8-insantiate-arrayallocator.patch" )

# The space required to build varies wildly depending on USE flags,
# ranging from 2GB to 16GB. This function is certainly not exact but
# should be close enough to be useful.
openjdk_check_requirements() {
	local M
	M=4096
	M=$(( $(usex debug 3 1) * $M ))
	M=$(( $(usex doc 320 0) + $(usex source 128 0) + 192 + $M ))

	CHECKREQS_DISK_BUILD=${M}M check-reqs_pkg_${EBUILD_PHASE}
}

pkg_pretend() {
	openjdk_check_requirements
	if [[ ${MERGE_TYPE} != binary ]]; then
		has ccache ${FEATURES} && die "FEATURES=ccache doesn't work with ${PN}, bug #677876"
	fi
}

pkg_setup() {
	openjdk_check_requirements

	JAVA_PKG_WANT_BUILD_VM="openjdk-${SLOT} openjdk-bin-${SLOT} icedtea-${SLOT} icedtea-bin-${SLOT}"
	JAVA_PKG_WANT_SOURCE="${SLOT}"
	JAVA_PKG_WANT_TARGET="${SLOT}"

	java-vm-2_pkg_setup
	java-pkg-2_pkg_setup
}

src_prepare() {
	default

	# new warnings in new gcc https://bugs.gentoo.org/685426
	sed -i '/^WARNINGS_ARE_ERRORS/ s/-Werror/-Wno-error/' \
		hotspot/make/linux/makefiles/gcc.make || die

	chmod +x configure || die
}

src_configure() {
	# general build info found here:
	#https://hg.openjdk.java.net/jdk8/jdk8/raw-file/tip/README-builds.html

	# Work around stack alignment issue, bug #647954.
	use x86 && append-flags -mincoming-stack-boundary=2

	# Work around -fno-common ( GCC10 default ), bug #706638
	append-flags -fcommon

	# Strip some flags users may set, but should not. #818502
	filter-flags -fexceptions

	tc-export_build_env CC CXX PKG_CONFIG STRIP

	local myconf=(
			--disable-ccache
			--disable-freetype-bundling
			--disable-precompiled-headers
			--enable-unlimited-crypto
			--with-boot-jdk="${JDK_HOME}"
			--with-extra-cflags="${CFLAGS}"
			--with-extra-cxxflags="${CXXFLAGS}"
			--with-extra-ldflags="${LDFLAGS}"
			--with-freetype-lib="$( $(tc-getPKG_CONFIG) --variable=libdir freetype2 )"
			--with-freetype-include="$( $(tc-getPKG_CONFIG) --variable=includedir freetype2)/freetype2"
			--with-giflib=system
			--with-jtreg=no
			--with-jobs=1
			--with-num-cores=1
			--with-update-version="$(ver_cut 2)"
			--with-build-number="b$(ver_cut 4)"
			--with-milestone="fcs" # magic variable that means "release version"
			--with-vendor-name="Funtoo"
			--with-vendor-url="https://funtoo.org"
			--with-vendor-bug-url="https://bugs.funtoo.org"
			--with-vendor-vm-bug-url="https://bugs.openjdk.java.net"
			--with-zlib=system
			--with-native-debug-symbols=$(usex debug internal none)
			$(usex headless-awt --disable-headful '')
			$(tc-is-clang && echo "--with-toolchain-type=clang")
		)

	(
		unset _JAVA_OPTIONS JAVA JAVA_TOOL_OPTIONS JAVAC MAKE XARGS
		CFLAGS= CXXFLAGS= LDFLAGS= \
		CONFIG_SITE=/dev/null \
		CONFIG_SHELL="${BROOT}/bin/bash"
		econf "${myconf[@]}"
	)
}

src_compile() {
	local myemakeargs=(
		JOBS=$(makeopts_jobs)
		LOG=debug
		CFLAGS_WARNINGS_ARE_ERRORS= # No -Werror
		NICE= # Use PORTAGE_NICENESS, don't adjust further down
		$(usex doc docs '')
		bootcycle-images
	)
	emake "${myemakeargs[@]}" -j1 #nowarn
}

src_install() {
	local dest="/usr/$(get_libdir)/${PN}-${SLOT}"
	local ddest="${ED}/${dest#/}"

	cd "${S}"/build/*-release/images/j2sdk-image || die

	if ! use alsa; then
		rm -v jre/lib/$(get_system_arch)/libjsoundalsa.* || die
	fi

	# build system does not remove that
	if use headless-awt ; then
		rm -fvr jre/lib/$(get_system_arch)/lib*{[jx]awt,splashscreen}* \
		{,jre/}bin/policytool bin/appletviewer || die
	fi

	if ! use examples ; then
		rm -vr demo/ || die
	fi

	if ! use source ; then
		rm -v src.zip || die
	fi

	dodir "${dest}"
	cp -pPR * "${ddest}" || die

	dosym8 -r /etc/ssl/certs/java/cacerts "${dest}"/jre/lib/security/cacerts

	java-vm_install-env "${FILESDIR}"/${PN}-${SLOT}.env.sh
	java-vm_set-pax-markings "${ddest}"
	java-vm_revdep-mask
	java-vm_sandbox-predict /dev/random /proc/self/coredump_filter

	if use doc ; then
		docinto html
		dodoc -r "${S}"/build/*-release/docs/*
	fi
}

pkg_postinst() {
	java-vm-2_pkg_postinst
	einfo "JavaWebStart functionality provided by icedtea-web package"
}