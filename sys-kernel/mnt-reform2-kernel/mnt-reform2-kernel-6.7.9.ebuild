# Copyright 2020-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

KERNEL_IUSE_GENERIC_UKI=1
KERNEL_IUSE_MODULES_SIGN=1

inherit kernel-build toolchain-funcs

MY_P=linux-${PV%.*}
GENPATCHES_P=genpatches-${PV%.*}-$(( ${PV##*.} + 4 ))
# https://koji.fedoraproject.org/koji/packageinfo?packageID=8
# forked to https://github.com/projg2/fedora-kernel-config-for-gentoo
CONFIG_VER=6.7.8-gentoo
GENTOO_CONFIG_VER=g11
REFORM_CONFIG_HASH=769abfe2cb0b189b1c20fdb9d62ffede25e7e388

DESCRIPTION="Linux kernel built with Gentoo patches"
HOMEPAGE="
	https://wiki.gentoo.org/wiki/Project:Distribution_Kernel
	https://wiki.gentoo.org/wiki/MNT_Reform
	https://source.mnt.re/reform/reform-debian-packages
	https://www.kernel.org/
"
SRC_URI+="
	https://cdn.kernel.org/pub/linux/kernel/v$(ver_cut 1).x/${MY_P}.tar.xz
	https://source.mnt.re/reform/reform-debian-packages/-/archive/${REFORM_CONFIG_HASH}/reform-debian-packages-${REFORM_CONFIG_HASH}.tar.gz
	https://dev.gentoo.org/~mpagano/dist/genpatches/${GENPATCHES_P}.base.tar.xz
	https://dev.gentoo.org/~mpagano/dist/genpatches/${GENPATCHES_P}.extras.tar.xz
	https://github.com/projg2/gentoo-kernel-config/archive/${GENTOO_CONFIG_VER}.tar.gz
		-> gentoo-kernel-config-${GENTOO_CONFIG_VER}.tar.gz
	https://raw.githubusercontent.com/projg2/fedora-kernel-config-for-gentoo/${CONFIG_VER}/kernel-aarch64-fedora.config
			-> kernel-aarch64-fedora.config.${CONFIG_VER}
"
S=${WORKDIR}/${MY_P}

LICENSE="GPL-2"
KEYWORDS="~arm64"
IUSE="debug hardened"

RDEPEND="
	!sys-kernel/gentoo-kernel-bin:${SLOT}
"
BDEPEND="
	debug? ( dev-util/pahole )
"
PDEPEND="
	>=virtual/dist-kernel-${PV}
"

QA_FLAGS_IGNORED="
	usr/src/linux-.*/scripts/gcc-plugins/.*.so
	usr/src/linux-.*/vmlinux
	usr/src/linux-.*/arch/powerpc/kernel/vdso.*/vdso.*.so.dbg
"

src_prepare() {
	local PATCHES=(
		# meh, genpatches have no directory
		"${WORKDIR}"/*.patch
		"${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches6.6/imx8mq-mnt-reform2/*.patch
		"${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches6.6/ls1028a-mnt-reform2/*.patch
	)
	default

	local biendian=false

	# prepare the default config
	case ${ARCH} in
		arm64)
			cp "${DISTDIR}/kernel-aarch64-fedora.config.${CONFIG_VER}" .config || die
			biendian=true
			;;
		*)
			die "Unsupported arch ${ARCH}"
			;;
	esac

	# Device tree for imx8mq
	mv ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/imx8mq-mnt-reform2.dts{,.orig}
	cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/imx8mq-mnt-reform2.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/imx8mq-mnt-reform2.dts
	cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/imx8mq-mnt-reform2-hdmi.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/imx8mq-mnt-reform2-hdmi.dts

	# Device tree for ls1028a
	sed --in-place --expression='/imx8mq-mnt-reform2.dtb/a dtb-$(CONFIG_ARCH_MXC) += imx8mq-mnt-reform2-hdmi.dtb' ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/Makefile
	cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/fsl-ls1028a-mnt-reform2.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/fsl-ls1028a-mnt-reform2.dts
	sed --in-place --expression='/fsl-ls1028a-rdb.dtb/a dtb-$(CONFIG_ARCH_LAYERSCAPE) += fsl-ls1028a-mnt-reform2.dtb' ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/Makefile

	local myversion="-gentoo-dist-reform2"
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

	use secureboot && merge_configs+=( "${dist_conf_path}/secureboot.config" )

	kernel-build_merge_configs "${merge_configs[@]}"
}
