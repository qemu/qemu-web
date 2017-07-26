---
title: Reporting a bug
permalink: /contribute/report-a-bug/
---

Bugs can be filed at our [bug tracker](https://bugs.launchpad.net/qemu/), which is hosted on Launchpad. If you've got a problem with how your Linux distribution packages QEMU, use the bug tracker from your distro instead.

When submitting a bug report, please try to do the following:

* Include the QEMU release version or the git commit hash into the description, so that it is later still clear in which version you have found the bug.  Reports against the [latest release](/download/#source) or even the latest development tree are usually acted upon faster.

* Include the full command line used to launch the QEMU guest.

* Reproduce the problem directly with a QEMU command-line.  Avoid frontends and management stacks, to ensure that the bug is in QEMU itself and not in a frontend.

* Include information about the host and guest (operating system, version, 32/64-bit).

* Do not contribute patches on the bug tracker; send patches to the mailing list. Follow QEMU's [guidelines about submitting patches](http://wiki.qemu.org/Contribute/SubmitAPatch).

Do NOT report security issues (or other bugs, too) as
"private" bugs in the bug tracker.  QEMU has a [security
process](http://wiki.qemu.org/SecurityProcess) for issues that should
be reported in a non-public way instead.

For problems with KVM in the kernel, use the kernel bug tracker instead;
the [KVM wiki](http://www.linux-kvm.org/page/Bugs) has the details.
