# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit java-vm-2

DESCRIPTION="Prebuilt Java JDK binaries provided by Eclipse Temurin"
HOMEPAGE="https://adoptium.net"
SRC_URI="
	amd64? ( https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jdk_x64_linux_hotspot_8u422b05.tar.gz -> OpenJDK8U-jdk_x64_linux_hotspot_8u422b05.tar.gz )
	arm64? ( https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jdk_aarch64_linux_hotspot_8u422b05.tar.gz -> OpenJDK8U-jdk_aarch64_linux_hotspot_8u422b05.tar.gz )
	ppc64? ( https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jdk_ppc64le_linux_hotspot_8u422b05.tar.gz -> OpenJDK8U-jdk_ppc64le_linux_hotspot_8u422b05.tar.gz )
	arm? ( https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jdk_arm_linux_hotspot_8u422b05.tar.gz -> OpenJDK8U-jdk_arm_linux_hotspot_8u422b05.tar.gz )"

LICENSE="GPL-2-with-classpath-exception"
KEYWORDS="-* amd64 arm arm64 ppc64"
SLOT=$(ver_cut 1)
IUSE="alsa cups examples headless-awt selinux source"

RDEPEND="
	>=sys-apps/baselayout-java-0.1.0-r1
	media-libs/fontconfig:1.0
	media-libs/freetype:2
	>=sys-libs/glibc-2.2.5:*
	sys-libs/zlib
	alsa? ( media-libs/alsa-lib )
	arm? ( dev-libs/libffi-compat:6 )
	cups? ( net-print/cups )
	selinux? ( sec-policy/selinux-java )
	!headless-awt? (
		x11-libs/libX11
		x11-libs/libXext
		x11-libs/libXi
		x11-libs/libXrender
		x11-libs/libXtst
	)
"

RESTRICT="preserve-libs strip"
QA_PREBUILT="*"

S="${WORKDIR}/jdk8u422-b05"

src_unpack() {
	default
	# 753575
	if use arm; then
		mv -v "${S}"* "${S}" || die
	fi
}

src_install() {
	local dest="/opt/${P}"
	local ddest="${ED}/${dest#/}"

	rm ASSEMBLY_EXCEPTION LICENSE THIRD_PARTY_README || die

	# this does not exist on arm64 hence -f
	rm -fv jre/lib/*/libfreetype.so* || die

	if ! use alsa ; then
		rm -v jre/lib/*/libjsoundalsa.so* || die
	fi

	if ! use examples ; then
		rm -vr sample || die
	fi

	if use headless-awt ; then
		rm -fvr {,jre/}lib/*/lib*{[jx]awt,splashscreen}* \
			{,jre/}bin/policytool bin/appletviewer || die
	fi

	if ! use source ; then
		rm -v src.zip || die
	fi

	rm -v jre/lib/security/cacerts || die
	dosym ../../../../../etc/ssl/certs/java/cacerts "${dest}"/jre/lib/security/cacerts

	dodir "${dest}"
	cp -pPR * "${ddest}" || die

	# provide stable symlink
	dosym "${P}" "/opt/${PN}-${SLOT}"

	java-vm_install-env "${FILESDIR}"/${PN}-${SLOT}.env.sh
	java-vm_set-pax-markings "${ddest}"
	java-vm_revdep-mask
	java-vm_sandbox-predict /dev/random /proc/self/coredump_filter
}