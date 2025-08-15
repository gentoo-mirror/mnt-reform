# Copyright 2020-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

KERNEL_IUSE_GENERIC_UKI=1
KERNEL_IUSE_MODULES_SIGN=1

inherit kernel-build toolchain-funcs verify-sig

MY_P=linux-${PV%.*}
PATCHSET=linux-gentoo-patches-6.15.9-r1
# https://koji.fedoraproject.org/koji/packageinfo?packageID=8
# forked to https://github.com/projg2/fedora-kernel-config-for-gentoo
CONFIG_VER=6.15.8-gentoo
GENTOO_CONFIG_VER=g16
SHA256SUM_DATE=20250815
REFORM_CONFIG_HASH=e84ec8fc74b080b921b605dabdfabf5fdbdf3980

DESCRIPTION="Linux kernel built with Gentoo patches and patches for the MNT Reform 2 laptop."
HOMEPAGE="
        https://wiki.gentoo.org/wiki/Project:Distribution_Kernel
        https://wiki.gentoo.org/wiki/MNT_Reform
        https://source.mnt.re/reform/reform-debian-packages
        https://mntre.com/reform.html
        https://www.kernel.org/
"
SRC_URI+="
        https://cdn.kernel.org/pub/linux/kernel/v$(ver_cut 1).x/${MY_P}.tar.xz
        https://source.mnt.re/reform/reform-debian-packages/-/archive/${REFORM_CONFIG_HASH}/reform-debian-packages-${REFORM_CONFIG_HASH}.tar.gz
		https://cdn.kernel.org/pub/linux/kernel/v$(ver_cut 1).x/patch-${PV}.xz
		https://dev.gentoo.org/~mgorny/dist/linux/${PATCHSET}.tar.xz
        https://github.com/projg2/gentoo-kernel-config/archive/${GENTOO_CONFIG_VER}.tar.gz
                -> gentoo-kernel-config-${GENTOO_CONFIG_VER}.tar.gz
		verify-sig? (
			https://cdn.kernel.org/pub/linux/kernel/v$(ver_cut 1).x/sha256sums.asc
				-> linux-$(ver_cut 1).x-sha256sums-${SHA256SUM_DATE}.asc
		)
        https://raw.githubusercontent.com/projg2/fedora-kernel-config-for-gentoo/${CONFIG_VER}/kernel-aarch64-fedora.config
                -> kernel-aarch64-fedora.config.${CONFIG_VER}
"

S=${WORKDIR}/${MY_P}

LICENSE="GPL-2"
KEYWORDS="~arm64"
IUSE="debug experimental hardened"

RDEPEND="
        !sys-kernel/gentoo-kernel-bin:${SLOT}
"
BDEPEND="
        debug? ( dev-util/pahole )
		verify-sig? ( >=sec-keys/openpgp-keys-kernel-20250702 )
"
PDEPEND="
        >=virtual/dist-kernel-${PV}
"

QA_FLAGS_IGNORED="
        usr/src/linux-.*/scripts/gcc-plugins/.*.so
        usr/src/linux-.*/vmlinux
        usr/src/linux-.*/arch/powerpc/kernel/vdso.*/vdso.*.so.dbg
"

VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/kernel.org.asc

src_unpack() {
    if use verify-sig; then
        cd "${DISTDIR}" || die 
        verify-sig_verify_signed_checksums \
            "linux-$(ver_cut 1).x-sha256sums-${SHA256SUM_DATE}.asc" \
            sha256 "${MY_P}.tar.xz patch-${PV}.xz"
        cd "${WORKDIR}" || die 
    fi  

    default
}

src_prepare() {

    default
	eapply "${WORKDIR}/patch-${PV}"

	local patch
	for patch in "${WORKDIR}/${PATCHSET}"/*.patch; do
		eapply "${patch}"
		# non-experimental patches always finish with Gentoo Kconfig
		# when ! use experimental, stop applying after it
		if [[ ${patch} == *Add-Gentoo-Linux-support-config-settings* ]] &&
			! use experimental
		then
			break
		fi
	done

    # Patches for the i.MX8MPlus
    for patch in  "${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches${PV%.*}/imx8mp-mnt-reform2/*.patch; do
		eapply "${patch}"
	done
    # Patches for the i.MX8MPlus pocket reform
    for patch in  "${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches${PV%.*}/imx8mp-mnt-pocket-reform/*/*.patch; do
		eapply "${patch}"
	done
    # Patches for the i.MX8MQ
    for patch in  "${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches${PV%.*}/imx8mq-mnt-reform2/*.patch; do
		eapply "${patch}"
	done
    # Patches for the LS1028A
    for patch in  "${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches${PV%.*}/ls1028a-mnt-reform2/*.patch; do
		eapply "${patch}"
	done
    # Patches for the Bananapi cm4
    for patch in  "${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches${PV%.*}/meson-g12b-bananapi-cm4-mnt-reform2/*.patch; do
		eapply "${patch}"
	done
    # Patches for the Bananapi cm4 pocket reform
    for patch in  "${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches${PV%.*}/meson-g12b-bananapi-cm4-mnt-pocket-reform/*.patch; do
		eapply "${patch}"
	done
    # Patches for the rk3588
    for patch in  "${WORKDIR}"/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/patches${PV%.*}/rk3588-mnt-reform2/*.patch; do
		eapply "${patch}"
	done

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

    # Device tree for i.MX8MQ
    # There is already a device tree for the mnt reform upstream. The necessary patches are applied automatically. No need for further action here.
    cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/imx8mq-mnt-reform2-hdmi.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/imx8mq-mnt-reform2-hdmi.dts
    sed --in-place --expression='/imx8mq-mnt-reform2.dtb/a dtb-$(CONFIG_ARCH_MXC) += imx8mq-mnt-reform2-hdmi.dtb' ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/Makefile

    # Device tree for i.MX8MPlus
    cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/imx8mp-mnt-reform2.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/imx8mp-mnt-reform2.dts
    sed --in-place --expression='/imx8mq-mnt-reform2.dtb/a dtb-$(CONFIG_ARCH_MXC) += imx8mp-mnt-reform2.dtb'  ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/Makefile

    # Device tree for i.MX8MPlus pocket reform
    cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/imx8mp-mnt-pocket-reform.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/imx8mp-mnt-pocket-reform.dts
    sed --in-place --expression='/imx8mq-mnt-reform2.dtb/a dtb-$(CONFIG_ARCH_MXC) += imx8mp-mnt-pocket-reform.dtb'  ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/Makefile

    # Device tree for LS1028A
    cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/fsl-ls1028a-mnt-reform2.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/fsl-ls1028a-mnt-reform2.dts
    sed --in-place --expression='/fsl-ls1028a-rdb.dtb/a dtb-$(CONFIG_ARCH_LAYERSCAPE) += fsl-ls1028a-mnt-reform2.dtb' ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/freescale/Makefile

    # Device tree for the Bananapi cm4
    # There is already a device tree for the mnt reform upstream. The necessary patches are applied automatically. No need for further action here.

    # Device tree for the Bananapi cm4 pocket reform
    cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/meson-g12b-bananapi-cm4-mnt-pocket-reform.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/amlogic/meson-g12b-bananapi-cm4-mnt-pocket-reform.dts
    sed --in-place --expression='/meson-g12b-bananapi-cm4-mnt-reform2.dtb/a dtb-$(CONFIG_ARCH_MESON) += meson-g12b-bananapi-cm4-mnt-pocket-reform.dtb' ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/amlogic/Makefile

	# Device tree for the rk3588 mnt reform 2
	# Since it is now shipped with the vanila kernel, so we don't need to make an entry in the Makefile, just override the vanilla dts.
    cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/rk3588-mnt-reform2.dts  ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/rockchip/rk3588-mnt-reform2.dts 

    # Device tree for the rk3588 pocket reform
    cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/rk3588-mnt-pocket-reform.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/rockchip/rk3588-mnt-pocket-reform.dts
    sed --in-place --expression='/rk3588-mnt-reform2.dtb/a dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-mnt-pocket-reform.dtb' ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/rockchip/Makefile

    # Device tree for the rk3588 reform2 dsi
    cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/rk3588-mnt-reform2-dsi.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/rockchip/rk3588-mnt-reform2-dsi.dts
    sed --in-place --expression='/rk3588-mnt-pocket-reform.dtb/a dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-mnt-reform2-dsi.dtb' ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/rockchip/Makefile

    # Device tree for the rk3588 reform next
    cp ${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/rk3588-mnt-reform-next.dts ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/rockchip/rk3588-mnt-reform-next.dts
    sed --in-place --expression='/rk3588-mnt-reform2-dsi.dtb/a dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-mnt-reform-next.dtb' ${WORKDIR}/${MY_P}/arch/arm64/boot/dts/rockchip/Makefile

    local myversion="-gentoo-dist-reform2"
    use hardened && myversion+="-hardened"
    echo "CONFIG_LOCALVERSION=\"${myversion}\"" > "${T}"/version.config || die
    local dist_conf_path="${WORKDIR}/gentoo-kernel-config-${GENTOO_CONFIG_VER}"
    local reform_conf_path="${WORKDIR}/reform-debian-packages-${REFORM_CONFIG_HASH}/linux/config"

    local merge_configs=(
            "${T}"/version.config
            "${dist_conf_path}"/base.config
			"${dist_conf_path}"/6.12+.config
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
