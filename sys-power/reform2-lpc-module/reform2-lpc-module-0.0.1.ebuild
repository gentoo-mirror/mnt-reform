EAPI=8

DESCRIPTION="MNT Reform 2 LPC driver"
HOMEPAGE="https://mnt.re"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~arm64"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

EGIT_REPO_URI="https://source.mnt.re/reform/reform-tools.git"
inherit git-r3
inherit linux-mod-r1

S="${WORKDIR}/${P}/lpc"

CONFIG_CHECK="OF POWER_SUPPLY SPI"

src_compile() {
	local modlist=(
		reform2_lpc=misc
	)
	linux-mod-r1_src_compile
}
