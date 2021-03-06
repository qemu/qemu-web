---
layout: post
title:  "Understanding QEMU devices"
date:   2018-02-09 13:30:00 -0600
author: Eric Blake
categories: blog
---
Here are some notes that may help newcomers understand what is
actually happening with QEMU devices:

With QEMU, one thing to remember is that we are trying to emulate what
an Operating System (OS) would see on bare-metal hardware.  Most
bare-metal machines are basically giant memory maps, where software
poking at a particular address will have a particular side effect (the
most common side effect is, of course, accessing memory; but other
common regions in memory include the register banks for controlling
particular pieces of hardware, like the hard drive or a network card,
or even the CPU itself).  The end-goal of emulation is to allow a
user-space program, using only normal memory accesses, to manage all
of the side-effects that a guest OS is expecting.

As an implementation detail, some hardware, like x86, actually has two
memory spaces, where I/O space uses different assembly codes than
normal; QEMU has to emulate these alternative accesses.  Similarly,
many modern CPUs provide themselves a bank of CPU-local registers
within the memory map, such as for an interrupt controller.

With certain hardware, we have virtualization hooks where the CPU
itself makes it easy to trap on just the problematic assembly
instructions (those that access I/O space or CPU internal registers,
and therefore require side effects different than a normal memory
access), so that the guest just executes the same assembly sequence as
on bare metal, but that execution then causes a trap to let user-space
QEMU then react to the instructions using just its normal user-space
memory accesses before returning control to the guest.  This is
supported in QEMU through "accelerators".

Virtualizing accelerators, such as KVM, can let a guest run nearly
as fast as bare metal, where the slowdowns are caused by each trap
from guest back to QEMU (a vmexit) to handle a difficult assembly
instruction or memory address.  QEMU also supports other virtualizing
accelerators (such as
[HAXM](https://www.qemu.org/2017/11/22/haxm-usage-windows/) or macOS's
Hypervisor.framework).

QEMU also has a TCG accelerator, which takes the guest assembly
instructions and compiles it on the fly into comparable host
instructions or calls to host helper routines; while not as fast as
hardware acceleration, it allows cross-hardware emulation, such as
running ARM code on x86.

The next thing to realize is what is happening when an OS is accessing
various hardware resources.  For example, most operating systems ship
with a driver that knows how to manage an IDE disk - the driver is
merely software that is programmed to make specific I/O requests to a
specific subset of the memory map (wherever the IDE bus lives, which
is specific to the the hardware board).  When the IDE controller
hardware receives those I/O requests it then performs the appropriate
actions (via DMA transfers or other hardware action) to copy data from
memory to persistent storage (writing to disk) or from persistent
storage to memory (reading from the disk).

When you first buy bare-metal hardware, your disk is uninitialized; you
install the OS that uses the driver to make enough bare-metal accesses
to the IDE hardware portion of the memory map to then turn the disk into
a set of partitions and filesystems on top of those partitions.

So, how does QEMU emulate this? In the big memory map it provides to
the guest, it emulates an IDE disk at the same address as bare-metal
would.  When the guest OS driver issues particular memory writes to
the IDE control registers in order to copy data from memory to
persistent storage, the QEMU accelerator traps accesses to that memory
region, and passes the request on to the QEMU IDE controller device
model.  The device model then parses the I/O requests, and emulates
them by issuing host system calls.  The result is that guest memory is
copied into host storage.

On the host side, the easiest way to emulate persistent storage is via
treating a file in the host filesystem as raw data (a 1:1 mapping of
offsets in the host file to disk offsets being accessed by the guest
driver), but QEMU actually has the ability to glue together a lot of
different host formats (raw,
[qcow2](https://gitlab.com/qemu-project/qemu/-/blob/master/docs/interop/qcow2.txt),
qed,
[vhdx](https://www.microsoft.com/en-us/download/details.aspx?id=34750),
...) and protocols (file system, block device,
[NBD](https://github.com/NetworkBlockDevice/nbd/blob/master/doc/proto.md),
[Ceph](https://ceph.com/), [gluster](https://www.gluster.org/), ...)
where any combination of host format and protocol can serve as the
backend that is then tied to the QEMU emulation providing the guest
device.

Thus, when you tell QEMU to use a host qcow2 file, the guest does not
have to know qcow2, but merely has its normal driver make the same
register reads and writes as it would on bare metal, which cause vmexits
into QEMU code, then QEMU maps those accesses into reads and writes in
the appropriate offsets of the qcow2 file.  When you first install the
guest, all the guest sees is a blank uninitialized linear disk
(regardless of whether that disk is linear in the host, as in raw
format, or optimized for random access, as in the qcow2 format); it is
up to the guest OS to decide how to partition its view of the hardware
and install filesystems on top of that, and QEMU does not care what
filesystems the guest is using, only what pattern of raw disk I/O
register control sequences are issued.

The next thing to realize is that emulating IDE is not always the most
efficient.  Every time the guest writes to the control registers, it
has to go through special handling, and vmexits slow down
emulation. Of course, different hardware models have different
performance characteristics when virtualized.  In general, however,
what works best for real hardware does not necessarily work best for
virtualization, and until recently, hardware was not designed to
operate fast when emulated by software such as QEMU.  Therefore, QEMU
includes paravirtualized devices that are designed specifically for
this purpose.

The meaning of "paravirtualization" here is slightly different from
the original one of "virtualization through cooperation between the
guest and host".  The QEMU developers have produced a specification
for a set of hardware registers and the behavior for those registers
which are designed to result in the minimum number of vmexits possible
while still accomplishing what a hard disk must do, namely,
transferring data between normal guest memory and persistent storage.
This specification is called virtio; using it requires installation of
a virtio driver in the guest.  While no physical device exists that
follows the same register layout as virtio, the concept is the same: a
virtio disk behaves like a memory-mapped register bank, where the
guest OS driver then knows what sequence of register commands to write
into that bank to cause data to be copied in and out of other guest
memory.  Much of the speedups in virtio come by its design - the guest
sets aside a portion of regular memory for the bulk of its command
queue, and only has to kick a single register to then tell QEMU to
read the command queue (fewer mapped register accesses mean fewer
vmexits), coupled with handshaking guarantees that the guest driver
won't be changing the normal memory while QEMU is acting on it.

As an aside, just like recent hardware is fairly efficient to emulate,
virtio is evolving to be more efficient to implement in hardware, of
course without sacrificing performance for emulation or
virtualization.  Therefore, in the future, you could stumble upon
physical virtio devices as well.

In a similar vein, many operating systems have support for a number of
network cards, a common example being the e1000 card on the PCI bus.
On bare metal, an OS will probe PCI space, see that a bank of
registers with the signature for e1000 is populated, and load the
driver that then knows what register sequences to write in order to
let the hardware card transfer network traffic in and out of the
guest.  So QEMU has, as one of its many network card emulations, an
e1000 device, which is mapped to the same guest memory region as a
real one would live on bare metal.

And once again, the e1000 register layout tends to require a lot of
register writes (and thus vmexits) for the amount of work the hardware
performs, so the QEMU developers have added the virtio-net card (a PCI
hardware specification, although no bare-metal hardware exists yet
that actually implements it), such that installing a virtio-net driver
in the guest OS can then minimize the number of vmexits while still
getting the same side-effects of sending network traffic.  If you tell
QEMU to start a guest with a virtio-net card, then the guest OS will
probe PCI space and see a bank of registers with the virtio-net
signature, and load the appropriate driver like it would for any other
PCI hardware.

In summary, even though QEMU was first written as a way of emulating
hardware memory maps in order to virtualize a guest OS, it turns out
that the fastest virtualization also depends on virtual hardware: a
memory map of registers with particular documented side effects that has
no bare-metal counterpart.  And at the end of the day, all
virtualization really means is running a particular set of assembly
instructions (the guest OS) to manipulate locations within a giant
memory map for causing a particular set of side effects, where QEMU is
just a user-space application providing a memory map and mimicking the
same side effects you would get when executing those guest instructions
on the appropriate bare metal hardware.

(This post is a slight update on an
[email](https://lists.gnu.org/archive/html/qemu-devel/2017-07/msg05939.html)
originally posted to the qemu-devel list back in July 2017).
