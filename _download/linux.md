QEMU is packaged by most Linux distributions:

* <strong>Arch:</strong> `pacman -S qemu`

* <strong>Debian/Ubuntu:</strong>
  * For full system emulation: `apt-get install qemu-system`
  * For emulating Linux binaries: `apt-get install qemu-user-static`

* <strong>Fedora:</strong> `dnf install @virtualization`

* <strong>Gentoo:</strong> `emerge --ask app-emulation/qemu`

* <strong>RHEL/CentOS:</strong> `yum install qemu-kvm`

* <strong>SUSE:</strong> `zypper install qemu`

Note: On most distributions, the above commands will install meta-packages
that pull in other packages with emulator binaries for all available
targets. Have a look at the package list of your distribution first if you
only need a subset of the targets.
