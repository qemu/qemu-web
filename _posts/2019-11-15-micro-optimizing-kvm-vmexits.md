---
layout: post
title: "Micro-Optimizing KVM VM-Exits"
date:   2019-11-15
author: Kashyap Chamarthy
categories: [kvm, optimizations]
---

Background on VM-Exits
----------------------

KVM (Kernel-based Virtual Machine) is the Linux kernel module that
allows a host to run virtualized guests (Linux, Windows, etc).  The KVM
"guest execution loop", with QEMU (the open source emulator and
virtualizer) as its user space, is roughly as follows: QEMU issues the
ioctl(), KVM_RUN, to tell KVM to prepare to enter the CPU's "Guest Mode"
-- a special processor mode which allows guest code to safely run
directly on the physical CPU.  The guest code, which is inside a "jail"
and thus cannot interfere with the rest of the system, keeps running on
the hardware until it encounters a request it cannot handle.  Then the
processor gives the control back (referred to as "VM-Exit") either to
kernel space, or to the user space to handle the request.  Once the
request is handled, native execution of guest code on the processor
resumes again.  And the loop goes on.

There are dozens of reasons for VM-Exits (Intel's Software Developer
Manual outlines 64 "Basic Exit Reasons").  For example, when a guest
needs to emulate the CPUID instruction, it causes a "light-weight exit"
to kernel space, because CPUID (among a few others) is emulated in the
kernel itself, for performance reasons.  But when the kernel _cannot_
handle a request, e.g. to emulate certain hardware, it results in a
"heavy-weight exit" to QEMU, to perform the emulation.  These VM-Exits
and subsequent re-entries ("VM-Enters"), even the light-weight ones, can
be expensive.  What can be done about it?

Guest workloads that are hard to virtualize
-------------------------------------------

At the 2019 edition of the KVM Forum in Lyon, kernel developer Andrea
Arcangeli addressed the kernel part of minimizing VM-Exits.

His talk touched on the cost of VM-Exits into the kernel, especially for
guest workloads (e.g. enterprise databases) that are sensitive to their
performance penalty.  However, these workloads cannot avoid triggering
VM-Exits with a high frequency.  Andrea then outlined some of the
optimizations he's been working on to improve the VM-Exit performance in
the KVM code path -- especially in light of applying mitigations for
speculative execution flaws (Spectre v2, MDS, L1TF).

Andrea gave a brief recap of the different kinds of speculative
execution attacks (retpolines, IBPB, PTI, SSBD, etc).  Followed by that
he outlined the performance impact of Spectre-v2 mitigations in context
of KVM.

The microbechmark: CPUID in a one million loop
----------------------------------------------

Andrea constructed a synthetic microbenchmark program (without any GCC
optimizations or caching) which runs the CPUID instructions one million
times in a loop.  This microbenchmark is meant to focus on measuring the
performance of a specific area of the code -- in this case, to test the
latency of VM-Exits.

While stressing that the results of these microbenchmarks do not
represent real-world workloads, he had two goals in mind with it: (a)
explain how the software mitigation works; and (b) to justify to the
broader community the value of the software optimizations he's working
on in KVM.

Andrea then reasoned through several interesting graphs that show how
CPU computation time gets impacted when you disable or enable the
various kernel-space mitigations for Spectre v2, L1TF, MDS, et al.

The proposal: "KVM Monolithic"
------------------------------

Based on his investigation, Andrea proposed a patch series, ["KVM
monolithc"](https://lwn.net/Articles/800870/), to get rid of the KVM
common module, 'kvm.ko'.  Instead the KVM common code gets linked twice
into each of the vendor-specific KVM modules, 'kvm-intel.ko' and
'kvm-amd.ko'.

The reason for doing this is that the 'kvm.ko' module indirectly calls
(via the "retpoline" technique) the vendor-specific KVM modules at every
VM-Exit, several times.  These indirect calls—via function pointers in
the C source code—were not optimal before, but the "retpoline"
mitigation (which isolates indirect branches, that allow a CPU to
execute code from arbitrary locations, from speculative execution) for
Spectre v2 compounds the problem, as it degrades performance.

This approach will result in a few MiB of increased disk space for
'kvm-intel.ko' and 'kvm-amd.ko', but the upside in saved indirect calls,
and the elimination of "retpoline" overhead at run-time more than
compensate for it.

With the "KVM Monolithic" patch series applied, Andrea's microbenchmarks
show a double-digit improvement in performance with default mitigations
(for Spectre v2, et al) enabled on both Intel 'VMX' and AMD 'SVM'.  And
with 'spectre_v2=off' or for CPUs with IBRS_ALL in ARCH_CAPABILITIES
"KVM monolithic" still improve[s] performance, albiet it's on the order
of 1%.

Conclusion
----------

Removal of the common KVM module has a non-negligible positive
performance impact.  And the "KVM Monolitic" patch series is still
actively being reviewed, modulo some pending clean-ups.  Based on the
upstream review discussion, KVM Maintainer, Paolo Bonzini, and other
reviewers seemed amenable to merge the series.

Although, we still have to deal with mitigations for 'indirect branch
prediction' for a long time, reducing the VM-Exit latency is important
in general; and more specifically, for guest workloads that happen to
trigger frequent VM-Exits, without having to disable Spectre v2
mitigations on the host, as Andrea stated in the cover letter of his
patch series.
