---
layout: post
title:  "Accelerating QEMU on Windows with HAXM"
date:   2017-11-22 15:00:00 +0800
author: Yu Ning
categories: [tutorials, HAXM]
---
In this post, I'm going to introduce a useful technique to people who are using,
or are interested in using, QEMU on Windows. Basically, you can make the most of
your hardware to accelerate QEMU virtual machines on Windows: starting with its
2.9.0 release, QEMU is able to take advantage of
[Intel HAXM][haxm-github] to run x86 and x86\_64 VMs with hardware acceleration.

If you have used QEMU on Linux, you have probably enjoyed the performance boost
brought by [KVM][qemu-accel-kvm]: the same VM runs a lot faster when you launch
QEMU with the `-accel kvm` (or `-enable-kvm`) option, thanks to
hardware-assisted virtualization. On Windows, you can achieve a similar speed-up
with `-accel hax` (or `-enable-hax`), after completing a one-time setup process.

First, make sure your host system meets the requirements of HAXM:
1. An Intel CPU that supports
[Intel VT-x with Extended Page Tables (EPT)][intel-vtx-ept-cpu-list].
  * Intel CPUs that do not support the said feature are almost extinct now. If
you have a Core i3/i5/i7, you should be good to go.
2. Windows 7 or later.
  * HAXM works on both 32-bit and 64-bit versions of Windows. For the rest of
this tutorial, I'll assume you are running 64-bit Windows, which is far more
popular than 32-bit nowadays.

Next, check your BIOS (or UEFI boot firmware) settings, and make sure VT-x
(or Virtualization Technology, depending on your BIOS) is enabled. If there is
also a setting for Execute Disable Bit, make sure that one is enabled as well.
In most cases, both settings are enabled by default.
  * If your system is protected against changes to BIOS, e.g. you have enabled
BitLocker Drive Encryption or any other tamper protection mechanism, you may
need to take preventive measures to avoid being locked out after changing the
said BIOS settings.

After that, if you are on Windows 8 or later, make sure Hyper-V is disabled.
This is especially important for Windows 10, which enables Hyper-V by default.
The reason is that Hyper-V makes exclusive use of VT-x, preventing HAXM and
other third-party hypervisors (such as VMware and VirtualBox) from seeing that
hardware feature. There are a number of ways to disable Hyper-V; one of them is
to bring up the *Start* menu, type *Windows Features* and Enter, uncheck
*Hyper-V* in the resulting dialog, and click on *OK* to confirm.
  * Note that changing the Hyper-V setting could also trigger the alarm of the
tamper protection mechanism (e.g. BitLocker) that may be enabled on your system.
Again, make sure you won't be locked out after the reboot.

![Disabling Hyper-V in Windows Features](/screenshots/windows-features-hyperv.png)

Now you're ready to install HAXM, which needs to run as a kernel-mode driver on
Windows so as to execute the privileged VT-x instructions. Simply download the
latest HAXM release for Windows [here][haxm-download], unzip, and run
`intelhaxm-android.exe` to launch the installation wizard. (Despite the file
name, Android is not the only guest OS that can be accelerated by HAXM.)

![Installing HAXM on Windows](/screenshots/haxm-installer-windows.png)

If you haven't installed QEMU, now is the time to do it. I recommend getting the
latest stable release from [here][qemu-download-w64]. At the time of this
writing, the latest stable release is 2.10.1 (build 20171006), so I downloaded
`qemu-w64-setup-20171006.exe`, which is an easy-to-use installer.

With all that, we're ready to launch a real VM in QEMU. You can use your
favorite QEMU disk image, provided that the guest OS installed there is
compatible with the x86 (i386) or x86\_64 (amd64) architecture. My choice for
this tutorial is `debian_wheezy_amd64_standard.qcow2`, which contains a fresh
installation of the standard Debian Wheezy system for x86\_64, available
[here][debian-qcow2-amd64]. To boot it, open a new command prompt window, switch
to your QEMU installation directory (e.g. `cd "C:\Program Files\qemu"`), and
run:

```
qemu-system-x86_64.exe -hda X:\path\to\debian_wheezy_amd64_standard.qcow2 -accel hax
```

You don't have to leave the screen as the VM boots up, because soon you'll be
able to see the Debian shell and log in.

![Debian Wheezy (Standard) booted up in QEMU+HAXM](/screenshots/qemu-debian-wheezy-shell-with-haxm.png)

To feel the difference made by HAXM acceleration, shut down the VM, and relaunch
it without `-accel hax`:

```
qemu-system-x86_64.exe -hda X:\path\to\debian_wheezy_amd64_standard.qcow2
```

If you're still not impressed, try a more sophisticated VM image such as
`debian_wheezy_amd64_desktop.qcow2`, which boots to a desktop environment. VMs
like this are hardly usable without hardware acceleration.

That's it! I hope HAXM gives you a more enjoyable QEMU experience on Windows.
You may run into issues at some point, because there are, inevitably, bugs in
HAXM (e.g. booting an ISO image from CD-ROM doesn't work at the moment). But the
good news is that HAXM is now open source on [GitHub][haxm-github], so everyone
can help improve it. Please create an issue on GitHub if you have a question,
bug report or feature request.

[haxm-github]: https://github.com/intel/haxm
[qemu-accel-kvm]: https://wiki.qemu.org/Features/KVM
[intel-vtx-ept-cpu-list]: https://ark.intel.com/Search/FeatureFilter?productType=processors&ExtendedPageTables=true
[haxm-download]: https://software.intel.com/en-us/articles/intel-hardware-accelerated-execution-manager-intel-haxm
[qemu-download-w64]: https://qemu.weilnetz.de/w64/
[debian-qcow2-amd64]: https://people.debian.org/~aurel32/qemu/amd64/
