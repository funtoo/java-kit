# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit java-vm-2

DESCRIPTION="Prebuilt Java JRE binaries provided by Eclipse Temurin"
HOMEPAGE="https://adoptium.net"
SRC_URI="
	amd64? ( https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jre_x64_linux_hotspot_8u422b05.tar.gz -> OpenJDK8U-jre_x64_linux_hotspot_8u422b05.tar.gz )
	arm64? ( https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jre_aarch64_linux_hotspot_8u422b05.tar.gz -> OpenJDK8U-jre_aarch64_linux_hotspot_8u422b05.tar.gz )
	ppc64? ( https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jre_ppc64le_linux_hotspot_8u422b05.tar.gz -> OpenJDK8U-jre_ppc64le_linux_hotspot_8u422b05.tar.gz )
	arm? ( https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jre_arm_linux_hotspot_8u422b05.tar.gz -> OpenJDK8U-jre_arm_linux_hotspot_8u422b05.tar.gz )"

LICENSE="GPL-2-with-classpath-exception"
KEYWORDS="-* amd64 arm arm64 ppc64"
SLOT="$(ver_cut 1)"
IUSE="alsa cups headless-awt selinux"

RDEPEND="
	media-libs/fontconfig:1.0
	media-libs/freetype:2
	>net-libs/libnet-1.1
	>=sys-apps/baselayout-java-0.1.0-r1
	>=sys-libs/glibc-2.2.5:*
	sys-libs/zlib
	alsa? ( media-libs/alsa-lib )
	cups? ( net-print/cups )
	selinux? ( sec-policy/selinux-java )
	!headless-awt? (
		x11-libs/libX11
		x11-libs/libXext
		x11-libs/libXi
		x11-libs/libXrender
		x11-libs/libXtst
	)"

RESTRICT="preserve-libs splitdebug"
QA_PREBUILT="*"

S="${WORKDIR}/jdk8u422-b05-jre"

src_install() {
	local dest="/opt/${P}"
	local ddest="${ED}/${dest#/}"

	rm ASSEMBLY_EXCEPTION LICENSE THIRD_PARTY_README || die

	# this does not exist on arm64 hence -f
	rm -fv lib/*/libfreetype.so* || die

	if ! use alsa ; then
		rm -v lib/*/libjsoundalsa.so* || die
	fi

	if use headless-awt ; then
		rm -fvr lib/*/lib*{[jx]awt,splashscreen}* \
			bin/policytool || die
	fi

	rm -v lib/security/cacerts || die
	dosym ../../../../../etc/ssl/certs/java/cacerts "${dest}"/lib/security/cacerts

	dodir "${dest}"
	cp -pPR * "${ddest}" || die

	# provide stable symlink
	dosym "${P}" "/opt/${PN}-${SLOT}"

	java-vm_install-env "${FILESDIR}"/${PN}-${SLOT}.env.sh
	java-vm_set-pax-markings "${ddest}"
	java-vm_revdep-mask
	java-vm_sandbox-predict /dev/random /proc/self/coredump_filter
}