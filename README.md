**warning** The kernel compiles but as of right now, it does not boot! I will update the README as soon as all is well.

A Gentoo repository / overlay for the [MNT reform 2 laptop](https://mntre.com/).

You can find here an ebuild for a patched and correctly configured kernel, called `sys-kernel/mnt-reform2-kernel`.

To add the repository to your system, run:
```bash
eselect repository add mnt-reform2 git https://git.chaostreffbern.ch/vimja/mnt-reform2-overlay.git
emerge --sync mnt-reform2
```

Then, install the kernel like so:
```bash
emerge --ask --verbose emerge --sync mnt-reform2
```
