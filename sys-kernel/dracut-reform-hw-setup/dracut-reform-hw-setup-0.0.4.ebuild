# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit toolchain-funcs

DESCRIPTION="Dracut module to run the reform-hw-setup script on MNT Reform laptops"
HOMEPAGE="https://source.mnt.re/vimja/dracut_reform-hw-setup"
S=${WORKDIR}/${PN}-v${PV}

SRC_URI="https://source.mnt.re/vimja/dracut_reform-hw-setup/-/archive/v${PV}/${PN}-v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~arm64"
IUSE="+mnt_reform_som_imx8mq mnt_reform_som_bpi-cm4 mnt_reform_som_ls1028a"

DEPEND="sys-kernel/dracut"
RDEPEND="mnt_reform_som_imx8mq? ( media-sound/alsa-utils )
	mnt_reform_som_bpi-cm4? ( media-sound/alsa-utils )
	mnt_reform_som_ls1028a? ( <dev-libs/libgpiod-2.0.0 )"

src_unpack() {
	default
}

src_install() {
	dodir /usr/lib/dracut/modules.d/99reform-hw-setup
	exeinto /usr/lib/dracut/modules.d/99reform-hw-setup
	doexe *.sh
}
