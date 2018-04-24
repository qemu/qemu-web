---
layout: post
title:  "QEMU 2.11.1 and making use of Spectre/Meltdown mitigation for KVM guests"
date: 2018-02-14 10:35:44 -0600
author: Michael Roth
categories: [meltdown, spectre, security, x86, ppc, s390, releases, 'qemu 2.11']
---

A [previous post](https://www.qemu.org/2018/01/04/spectre/) detailed how
QEMU/KVM might be affected by Spectre/Meltdown attacks, and what the plan
was to mitigate them in QEMU 2.11.1 (and eventually QEMU 2.12).

QEMU 2.11.1 is now available, and contains the aforementioned mitigation
functionality for x86 guests, along with additional mitigation functionality
for pseries and s390x guests (ARM guests do not currently require additional
QEMU patches).  However, enabling this functionality requires additional
configuration beyond just updating QEMU, which we want to address with this
post.

Please note that QEMU/KVM has at least the same requirements as other
unprivileged processes running on the host with regard to Spectre/Meltdown
mitigation. What is being addressed here is enabling a guest operating system
to enable the same (or similar) mitigations to protect itself from
unprivileged guest processes running under the guest operating system. Thus,
the patches/requirements listed here are specific to that goal and should not
be regarded as the full set of requirements to enable mitigations on the host
side (though in some cases there is some overlap between the two with regard
to required patches/etc).

Also please note that this is a best-effort from the QEMU/KVM community, and
these mitigations rely on a mix of additional kernel/firmware/microcode
updates that are in some cases not yet available publicly, or may not yet be
implemented in some distros, so users are highly encouraged to consult with
their respective vendors/distros to confirm whether all the required
components are in place. We do our best to highlight the requirements here,
but this may not be an exhaustive list.


## Enabling mitigation features for x86 KVM guests

**Note: these mitigations are known to cause some [performance degradation][1] for
certain workloads (whether used on host or guest), and for some Intel
architectures alternative solutions like retpoline-based kernels may be
available which [may provide similar levels of mitigation][2] with reduced
performance impact. Please check with your distro/vendor to see what options
are available to you.**

For x86 guests there are 2 additional CPU flags associated with
Spectre/Meltdown mitigation: **spec-ctrl**, and **ibpb**:

* spec-ctrl: exposes Indirect Branch Restricted Speculation (IBRS)
* ibpb: exposes Indirect Branch Prediction Barriers

These flags expose additional functionality made available through new
microcode updates for certain Intel/AMD processors that can be used to
mitigate various attack vectors related to Spectre. (Meltdown mitigation
via KPTI does not require additional CPU functionality or microcode, and
does not require an updated QEMU, only the related guest/host kernel
patches).

Utilizing this functionality requires guest/host kernel updates, as well
as microcode updates for Intel and recent AMD processors. The status of
these kernel patches upstream is still in flux, but most supported
distros have some form of the patches that is sufficient to make use
of the functionality. The current status/availability of microcode updates
depends on your CPU architecture/model. Please check with your
vendor/distro to confirm these prerequisites are available/installed.

Generally, for Intel CPUs with updated microcode, **spec-ctrl** will
enable both IBRS and IBPB functionality. For AMD EPYC processors,
**ibpb** can be used to enable IBPB specifically, and is thought to
be sufficient by itself for that particular architecture.

These flags can be set in a similar manner as other CPU flags, i.e.:

    qemu-system-x86_64 -cpu qemu64,+spec-ctrl,... ...
    qemu-system-x86_64 -cpu IvyBridge,+spec-ctrl,... ...
    qemu-system-x86_64 -cpu EPYC,+ibpb,... ...
    etc...

Additionally, for management stacks that lack support for setting
specific CPU flags, a set of new CPU types have been added which
enable the appropriate CPU flags automatically:

    qemu-system-x86_64 -cpu Nehalem-IBRS ...
    qemu-system-x86_64 -cpu Westmere-IBRS ...
    qemu-system-x86_64 -cpu SandyBridge-IBRS ...
    qemu-system-x86_64 -cpu IvyBridge-IBRS ...
    qemu-system-x86_64 -cpu Haswell-IBRS ...
    qemu-system-x86_64 -cpu Haswell-noTSX-IBRS ...
    qemu-system-x86_64 -cpu Broadwell-IBRS ...
    qemu-system-x86_64 -cpu Broadwell-noTSX-IBRS ...
    qemu-system-x86_64 -cpu Skylake-Client-IBRS ...
    qemu-system-x86_64 -cpu Skylake-Server-IBRS ...
    qemu-system-x86_64 -cpu EPYC-IBPB ...

With these settings enabled, guests may still require additional
configuration to enable IBRS/IBPB, which may vary somewhat from one
distro to another. For RHEL guests, the following resource may be
useful:

* [https://access.redhat.com/articles/3311301](https://access.redhat.com/articles/3311301)

With regard to migration compatibility, **spec-ctrl**/**ibrs** (or the
corresponding CPU type) should be set the same on both source/target to
maintain compatibility. Thus, guests will need to be rebooted to make
use of the new features.


## Enabling mitigation features for pseries KVM guests

For pseries guests there are 3 tri-state -machine options/capabilities
relating to Spectre/Meltdown mitigation: **cap-cfpc**, **cap-sbbc**,
**cap-ibs**, which each correspond to a set of host machine capabilities
advertised by the KVM kernel module in new/patched host kernels that can
be used to mitigate various aspects of Spectre/Meltdown:

* cap-cfpc: Cache Flush on Privilege Change
* cap-sbbc: Speculation Barrier Bounds Checking
* cap-ibs: Indirect Branch Serialisation

Each option can be set to one of "broken", "workaround", or "fixed", which
correspond, respectively, to instructing the guest whether the host is
vulnerable, has OS-level workarounds available, or has hardware/firmware
that does not require OS-level workarounds. Based on these options, QEMU
will perform checks to validate whether the specified settings are available
on the current host and pass these settings on to the guest kernel. At a
minimum, any setting other than "broken" will require a host kernel that has
some form of the following patches:

    commit 3214d01f139b7544e870fc0b7fcce8da13c1cb51
    KVM: PPC: Book3S: Provide information about hardware/firmware CVE workarounds
    
    commit 191eccb1580939fb0d47deb405b82a85b0379070
    powerpc/pseries: Add H_GET_CPU_CHARACTERISTICS flags & wrapper

and whether a host will support "workaround" and "fixed" settings for each
option will depend on the hardware/firmware level of the host system.

In turn, to make use of "workaround" or "fixed" settings for each option,
the guest kernel will require at least the following set of patches:

* [https://lists.ozlabs.org/pipermail/linuxppc-dev/2018-January/167455.html](https://lists.ozlabs.org/pipermail/linuxppc-dev/2018-January/167455.html)

These are available upstream and have been backported to a number of stable
kernels. Please check with your vendor/distro to confirm the required
hardware/firmware and guest kernel patches are available/installed.

All three options, **cap-cfpc**, **cap-sbbc**, and **cap-ibs** default
to "broken" to maintain compatibility with previous versions of QEMU
and unpatched host kernels. To enable them you must start QEMU with the
desired mitigation strategy specified explicitly. For example:

    qemu-system-ppc64 ... \
      -machine pseries-2.11,cap-cfpc=workaround,cap-sbbc=workaround,cap-ibs=fixed

With regard to migration compatibility, setting any of these features to a
value other than "broken" will require an identical setting for that option on
the source/destination guest. To enable these settings your guests will need to
be rebooted at some point.


## Enabling mitigation features for s390x KVM guests

For s390x guests there are 2 CPU feature bits relating to Spectre/Meltdown:

* bpb: Branch prediction blocking
* ppa15: PPA15 is installed

**bpb** requires a host kernel patched with:

    commit 35b3fde6203b932b2b1a5b53b3d8808abc9c4f60
    KVM: s390: wire up bpb feature

and both **bpb** and **ppa15** require a firmware with the appropriate support
level as well as guest kernel patches to enable the functionality within
guests. Please check with your distro/vendor to confirm.

Both **bpb** and **ppa15** are enabled by default when using "-cpu host"
and when the host kernels supports these facilities. For other CPU
models, the flags have to be set manually. For example:

    qemu-system-s390x -M s390-ccw-virtio-2.11 ... \
      -cpu zEC12,bpb=on,ppa15=on

With regard to migration, enabling **bpb** or **ppa15** feature flags requires
that the source/target also has those flags enabled. Since this is enabled by
default for '-cpu host' (when available on the host), you must ensure that
**bpb**=off,**ppa15**=off is used if you wish to maintain migration
compatibility with existing guests when using '-cpu host', or take steps to
reboot guests with **bpb**/**ppa15** enabled prior to migration.

[1] https://wiki.ubuntu.com/SecurityTeam/KnowledgeBase/SpectreAndMeltdown/PublishedApplicationData
[2] https://software.intel.com/sites/default/files/managed/1d/46/Retpoline-A-Branch-Target-Injection-Mitigation.pdf
