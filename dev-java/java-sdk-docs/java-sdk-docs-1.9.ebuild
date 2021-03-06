# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit versionator

DOWNLOAD_URL="http://www.oracle.com/technetwork/java/javase/documentation/jdk9-doc-downloads-3850606.html"

[[ "$(get_version_component_range 4)" == 0 ]] \
	|| MY_PV_EXT="$(get_version_component_range 4)"

MY_PV="$(get_version_component_range 2)${MY_PV_EXT}"
ORIG_NAME="jdk-${MY_PV}_doc-all.zip"

DESCRIPTION="Oracle's documentation bundle (including API) for Java SE"
HOMEPAGE="http://download.oracle.com/javase/9/docs/"
SRC_URI="${ORIG_NAME}"
LICENSE="oracle-java-documentation-9"
SLOT="1.9"
KEYWORDS="*"
RESTRICT="fetch"

DEPEND="app-arch/unzip"

S="${WORKDIR}/docs"

pkg_nofetch() {
	einfo "Please download ${ORIG_NAME} from "
	einfo "${DOWNLOAD_URL}"
	einfo "(agree to the license) and place it in ${DISTDIR}"

	einfo "If you find the file on the download page replaced with a higher"
	einfo "version, please report to the bug 67266 (link below)."
	einfo "If emerge fails because of a checksum error it is possible that"
	einfo "the upstream release changed without renaming. Try downloading the file"
	einfo "again (or a newer revision if available). Otherwise report this to"
	einfo "https://bugs.gentoo.org/67266 and we will make a new revision."
}

src_install(){
	insinto /usr/share/doc/${P}/html
	doins -r index.html */
}
