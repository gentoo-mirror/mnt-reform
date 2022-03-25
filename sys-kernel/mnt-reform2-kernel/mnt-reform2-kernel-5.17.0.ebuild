# Copyright 2020-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit kernel-build toolchain-funcs

MY_P=linux-${PV}
# https://koji.fedoraproject.org/koji/packageinfo?packageID=8
CONFIG_VER=5.17.0
FEDORA_CONFIG_HASH=6eb15e4d5d5c6d68a03bc9f42fd508e1e2523e55
REFORM_CONFIG_HASH=64ba0de7cfd90de442d76efca682a6755b353fa0
GENTOO_CONFIG_VER=5.15.5

DESCRIPTION="Linux kernel built from vanilla upstream sources"
HOMEPAGE="https://www.kernel.org/"
SRC_URI+="
	https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.17.tar.xz
	https://source.mnt.re/reform/reform-debian-packages/-/archive/${REFORM_CONFIG_HASH}/reform-debian-packages-${REFORM_CONFIG_HASH}.tar.gz
	https://github.com/mgorny/gentoo-kernel-config/archive/v${GENTOO_CONFIG_VER}.tar.gz
		-> gentoo-kernel-config-${GENTOO_CONFIG_VER}.tar.gz
	amd64? (
		https://src.fedoraproject.org/rpms/kernel/raw/${FEDORA_CONFIG_HASH}/f/kernel-x86_64-fedora.config
			-> kernel-x86_64-fedora.config.${CONFIG_VER}
	)
	arm64? (
		https://src.fedoraproject.org/rpms/kernel/raw/${FEDORA_CONFIG_HASH}/f/kernel-aarch64-fedora.config
			-> kernel-aarch64-fedora.config.${CONFIG_VER}
	)
	ppc64? (
		https://src.fedoraproject.org/rpms/kernel/raw/${FEDORA_CONFIG_HASH}/f/kernel-ppc64le-fedora.config
			-> kernel-ppc64le-fedora.config.${CONFIG_VER}
	)
	x86? (
		https://src.fedoraproject.org/rpms/kernel/raw/${FEDORA_CONFIG_HASH}/f/kernel-i686-fedora.config
			-> kernel-i686-fedora.config.${CONFIG_VER}
	)
"
S=${WORKDIR}/${MY_P}

LICENSE="GPL-2"
KEYWORDS="~amd64 ~arm ~arm64 ~ppc ~ppc64 ~x86"
IUSE="debug hardened"
REQUIRED_USE="arm? ( savedconfig )"

BDEPEND="
	debug? ( dev-util/pahole )
"
PDEPEND="
	>=virtual/dist-kernel-${PV}
"

VERIFY_SIG_OPENPGP_KEY_PATH=${BROOT}/usr/share/openpgp-keys/kernel.org.asc

src_unpack() {
	default
	mv ${WORKDIR}/linux-* ${WORKDIR}/${MY_P}
}

src_prepare() {
	local PATCHES=(
		"${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches/*.patch
	)
	default

	local biendian=false

	# prepare the default config
	case ${ARCH} in
		amd64)
			cp "${DISTDIR}/kernel-x86_64-fedora.config.${CONFIG_VER}" .config || die
			;;
		arm)
			return
			;;
		arm64)
			cp "${DISTDIR}/kernel-aarch64-fedora.config.${CONFIG_VER}" .config || die
			biendian=true
			;;
		hppa)
			return
			;;
		ppc)
			# assume powermac/powerbook defconfig
			# we still package.use.force savedconfig
			cp "${WORKDIR}/${MY_P}/arch/powerpc/configs/pmac32_defconfig" .config || die
			;;
		ppc64)
			cp "${DISTDIR}/kernel-ppc64le-fedora.config.${CONFIG_VER}" .config || die
			biendian=true
			;;
		x86)
			cp "${DISTDIR}/kernel-i686-fedora.config.${CONFIG_VER}" .config || die
			;;
		*)
			die "Unsupported arch ${ARCH}"
			;;
	esac

	mv ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/imx8mq-mnt-reform2.dts{,.orig}
	cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/imx8mq-mnt-reform2.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/imx8mq-mnt-reform2.dts

	local myversion="-mnt-reform2"
	use hardened && myversion+="-hardened"
	echo "CONFIG_LOCALVERSION=\"${myversion}\"" > "${T}"/version.config || die
	local dist_conf_path="${WORKDIR}/gentoo-kernel-config-${GENTOO_CONFIG_VER}"
	local reform_conf_path="${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/config"

	local merge_configs=(
		"${T}"/version.config
		"${dist_conf_path}"/base.config
		"${reform_conf_path}"
		"${FILESDIR}"/config
	)
	use debug || merge_configs+=(
		"${dist_conf_path}"/no-debug.config
	)
	if use hardened; then
		merge_configs+=( "${dist_conf_path}"/hardened-base.config )

		tc-is-gcc && merge_configs+=( "${dist_conf_path}"/hardened-gcc-plugins.config )

		if [[ -f "${dist_conf_path}/hardened-${ARCH}.config" ]]; then
			merge_configs+=( "${dist_conf_path}/hardened-${ARCH}.config" )
		fi
	fi

	# this covers ppc64 and aarch64_be only for now
	if [[ ${biendian} == true && $(tc-endian) == big ]]; then
		merge_configs+=( "${dist_conf_path}/big-endian.config" )
	fi

	kernel-build_merge_configs "${merge_configs[@]}"
}
