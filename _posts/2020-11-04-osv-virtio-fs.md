---
layout: post
title:  "Using virtio-fs on a unikernel"
author: Fotis Xenakis
date:   2020-11-04 02:00:00 +0200
categories: [storage, virtio-fs, unikernel, OSv]
---

This article provides an overview of [virtio-fs](https://virtio-fs.gitlab.io/),
a novel way for sharing the host file system with guests and
[OSv](https://github.com/cloudius-systems/osv), a specialized, lightweight
operating system (unikernel) for the cloud, as well as how these two fit
together.

## virtio-fs

Virtio-fs is a new host-guest shared filesystem, purpose-built for local file
system semantics and performance. To that end, it takes full advantage of the
host's and the guest's colocation on the same physical machine, unlike
network-based efforts, like virtio-9p.

As the name suggests, virtio-fs builds on virtio for providing an efficient
transport: it is included in the (currently draft, to become v1.2) virtio
[specification](https://github.com/oasis-tcs/virtio-spec) as a new device. The
protocol used by the device is a slightly extended version of
[FUSE](https://github.com/libfuse/libfuse), providing a solid foundation for
all file system operations native on Linux. Implementation-wise, on the QEMU
side, it takes the approach of splitting between the guest interface (handled
by QEMU) and the host file system interface (the device "backend"). The latter
is handled by virtiofsd ("virtio-fs daemon"), running as a separate process,
utilizing the
[vhost-user](https://www.qemu.org/docs/master/interop/vhost-user.html) protocol
to communicate with QEMU.

One prominent performance feature of virtio-fs is the DAX (Direct Access)
window. It's a shared memory window between the host and the guest, exposed as
device memory (a PCI BAR) to the second. Upon request, the host (QEMU) maps file contents to the window for the guest to access directly. This bears performance
gains due to taking VMEXITs out of the read/write data path and bypassing the
guest page cache on Linux, while not counting against the VM's memory (since
it's just device memory, managed on the host).

![virtio-fs DAX architecture](https://gitlab.com/virtio-fs/virtio-fs.gitlab.io/-/raw/master/architecture.svg)

Virtio-fs is under active development, with its community focussing on a pair of
device implementation in QEMU and device driver in Linux. Both components are
already available upstream in their initial iterations, while upstreaming
continues further e.g. with DAX window support.

## OSv

OSv is a [unikernel](https://en.wikipedia.org/wiki/Unikernel) (framework). The
two defining characteristics of a unikernel are:

- **Application-specialized**: a unikernel is an executable machine image,
  consisting of an application and supporting code (drivers, memory management,
  runtime etc.) linked together, running in a single address space (typically
  in guest "kernel mode").
- **Library OS**: each unikernel only contains the functionality mandated by its
  application in terms of non-application code, i.e. no unused drivers, or even
  whole subsystems (e.g. networking, if the application doesn't use the
  network).

OSv in particular strives for binary compatibility with Linux, using a [dynamic
linker](https://github.com/cloudius-systems/osv/wiki/Dynamic-Linker). This means
that applications built for Linux should run as OSv unikernels without requiring
modifications or even rebuilding, at least most of the time. Of course, not the
whole Linux ABI is supported, with system calls like `fork()` and relatives
missing by design in all unikernels, which lack the notion of a process. Despite
this limitation, OSv is quite full featured, with full SMP support, virtual
memory, a virtual file system (and many filesystem implementations, including
ZFS) as well as a mature networking stack, based on the FreeBSD sources.

At this point, one is sure to wonder "Why bother with unikernels?". The problem
they were originally
[introduced](http://unikernel.org/files/2013-asplos-mirage.pdf) to solve is the
bloated software stack in modern cloud computing. Running general-purpose
operating systems as guests, typically for a single application/service, on top
of a hypervisor which already takes care of isolation and provides a standard
device model means duplication, as well as loss of efficiency. This is were
unikernels come in, trying to be just enough to support a single application
and as light-weight as possible, based on the assumption that they are executing
inside a VM. Below is an illustration of the comparison between
general-purpose OS, unikernels and containers (as another approach to the same
problem, for completeness).

![Unikernels vs GPOS vs containers](/screenshots/2020-11-04-unikernel-vs-gpos.svg)

## OSv, meet virtio-fs

As is apparent e.g. from the container world, it is very common for applications
running in isolated environments (such as containers, or unikernels even more
so) to require host file system access. Whereas containers sharing the host
kernel thus have an obvious, controlled path to the host file system, with
unikernels this has been more complex: all solutions were somewhat heavyweight,
requiring a network link or indirection through network protocols. Virtio-fs
then provided a significantly more attractive route: straight-forward mapping of
fs operations (via FUSE), reusing the existing virtio transport and decent
performance without high memory overhead.

The OSv community quickly identified the opportunity and came up with a
read-only implementation on its side, when executing under QEMU. This emphasized
being lightweight complexity-wise, while catering to many of its applications'
requirements (they are stateless, think e.g. serverless). Notably, it includes
support for the DAX window (even before that's merged in upstream QEMU),
providing [excellent performance](https://github.com/foxeng/diploma), directly
rivalling that of its local (non-shared) counterparts such as ZFS and ROFS (an
OSv-specific read-only file system).

One central point is OSv's support for booting from virtio-fs: this enables
deploying a modified version or a whole new application **without rebuilding**
the image, just by adjusting its root file system contents on the host. Last,
owing to the DAX window practically providing low-overhead access to the host's
page cache, scalability is also expected to excel, with it being a common
concern due to the potentially high density of unikernels per host.

For example, to build the `cli` OSv image, bootable from virtio-fs, using the
core OSv [build
system](https://github.com/cloudius-systems/osv#building-osv-kernel-and-creating-images):
```
scripts/build fs=virtiofs export=all image=cli
```
This results in a minimal image (just the initramfs), while the root fs contents
are placed in a directory on the host (`build/export` here, by default).

[Running](https://github.com/cloudius-systems/osv#running-osv) the above image
is just a step away (may want to use the virtio-fs development version of
[QEMU](https://gitlab.com/virtio-fs/qemu/-/tree/virtio-fs-dev), e.g. for DAX
window support):
```
scripts/run.py --virtio-fs-tag=myfs --virtio-fs-dir=$(pwd)/build/export
```
This orchestrates running both virtiofsd and QEMU, using the contents of
`build/export` as the root file system. Any changes to this directory, directly
from the host will be visible in the guest without re-running the previous build
step.

## Conclusion

OSv has gained a prominent new feature, powered by virtio-fs and its QEMU
implementation. This allows efficient, lightweight and performant access to the
host's file system, thanks to the native virtio transport, usage of the FUSE
protocol and the DAX window architecture. In turn, it enables use cases like
rapid unikernel reconfiguration.
