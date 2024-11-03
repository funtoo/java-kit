# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit java-vm-2

DESCRIPTION="Prebuilt Java JDK binaries provided by Eclipse Temurin"
HOMEPAGE="https://adoptium.net"
SRC_URI="
	amd64? ( https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.4%2B7/OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz -> OpenJDK21U-jdk_x64_linux_hotspot_21.0.4_7.tar.gz )
	arm64? ( https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.4%2B7/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.4_7.tar.gz -> OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.4_7.tar.gz )
	riscv64? ( https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.4%2B7/OpenJDK21U-jdk_riscv64_linux_hotspot_21.0.4_7.tar.gz -> OpenJDK21U-jdk_riscv64_linux_hotspot_21.0.4_7.tar.gz )
	ppc64? ( https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.4%2B7/OpenJDK21U-jdk_ppc64le_linux_hotspot_21.0.4_7.tar.gz -> OpenJDK21U-jdk_ppc64le_linux_hotspot_21.0.4_7.tar.gz )"

LICENSE="GPL-2-with-classpath-exception"
KEYWORDS="-* amd64 arm64 ppc64 riscv64"
SLOT=$(ver_cut 1)
IUSE="alsa cups headless-awt selinux source"

RDEPEND="
	>=sys-apps/baselayout-java-0.1.0-r1
	media-libs/fontconfig:1.0
	media-libs/freetype:2
	media-libs/harfbuzz
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
	)"

RESTRICT="preserve-libs splitdebug"
QA_PREBUILT="*"

S="${WORKDIR}/jdk-21.0.4+7"

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

	# Not sure why they bundle this as it's commonly available and they
	# only do so on x86_64. It's needed by libfontmanager.so. IcedTea
	# also has an explicit dependency while Oracle seemingly dlopens it.
	rm -vf lib/libfreetype.so || die

	# prefer system copy # https://bugs.gentoo.org/776676
	rm -vf lib/libharfbuzz.so || die

	# Oracle and IcedTea have libjsoundalsa.so depending on
	# libasound.so.2 but AdoptOpenJDK only has libjsound.so. Weird.
	if ! use alsa ; then
		rm -v lib/libjsound.* || die
	fi

	if use headless-awt ; then
		rm -v lib/lib*{[jx]awt,splashscreen}* || die
	fi

	if ! use source ; then
		rm -v lib/src.zip || die
	fi

	rm -v lib/security/cacerts || die
	dosym ../../../../etc/ssl/certs/java/cacerts "${dest}"/lib/security/cacerts

	dodir "${dest}"
	cp -pPR * "${ddest}" || die

	# provide stable symlink
	dosym "${P}" "/opt/${PN}-${SLOT}"

	java-vm_install-env "${FILESDIR}"/${PN}.env.sh
	java-vm_set-pax-markings "${ddest}"
	java-vm_revdep-mask
	java-vm_sandbox-predict /dev/random /proc/self/coredump_filter
}

pkg_postinst() {
	java-vm-2_pkg_postinst
}