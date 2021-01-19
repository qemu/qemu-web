---
layout: post
title:  "Configuring virtio-blk and virtio-scsi Devices"
date:   2021-01-19 07:00:00 +0000
author: Stefan Hajnoczi and Sergio Lopez
categories: [storage]
---
The [previous article](https://www.qemu.org/2020/09/14/qemu-storage-overview/)
in this series introduced QEMU storage concepts. Now we move on to look at the
two most popular emulated storage controllers for virtualization: virtio-blk
and virtio-scsi.

This post provides recommendations for configuring virtio-blk and virtio-scsi
and how to choose between the two devices. The recommendations provide good
performance in a wide range of use cases and are suitable as default settings
in tools that use QEMU.

## Virtio storage devices
### Key points
* Prefer virtio storage devices over other emulated storage controllers.
* Use the latest virtio drivers.

Virtio devices are recommended over other emulated storage controllers as they
are generally the most performant and fully-featured storage controllers in
QEMU.

Unlike emulations of hardware storage controllers, virtio-blk and virtio-scsi
are specifically designed and optimized for virtualization. The details of how
they work are published for driver and device implementors in the [VIRTIO
specification](https://docs.oasis-open.org/virtio/virtio/v1.1/virtio-v1.1.html).

Virtio drivers are available for Linux, Windows, and other operating systems.
Installing the latest version is recommended for the latest bug fixes and
performance enhancements.

If virtio drivers are not available, the AHCI (SATA) device is widely supported
by modern x86 operating systems and can be used as a fallback. On non-x86
guests the default storage controller can be used as a fallback.

## Comparing virtio-blk and virtio-scsi
### Key points
* Prefer virtio-blk in performance-critical use cases.
* Prefer virtio-scsi for attaching more than 28 disks or for full SCSI support.
* With virtio-scsi, use scsi-block for SCSI passthrough and otherwise use scsi-hd.

Two virtio storage controllers are available: virtio-blk and virtio-scsi.

### virtio-blk
The virtio-blk device presents a block device to the virtual machine. Each
virtio-blk device appears as a disk inside the guest. virtio-blk was available
before virtio-scsi and is the most widely deployed virtio storage controller.

The virtio-blk device offers high performance thanks to a thin software stack
and is therefore a good choice when performance is a priority. It does not
support non-disk devices such as CD-ROM drives.

CD-ROMs and in general any application that sends SCSI commands are better
served by the virtio-scsi device, which has full SCSI support. SCSI passthrough
was removed from the Linux virtio-blk driver in v5.6 in favor of using
virtio-scsi.

Virtual machines that require access to many disks can hit limits based on
availability of PCI slots, which are under contention with other devices
exposed to the guest, such as NICs. For example a typical i440fx machine type
default configuration allows for about 28 disks. It is possible to use
multi-function devices to pack multiple virtio-blk devices into a single PCI
slot at the cost of losing hotplug support, or additional PCI busses can be
defined. Generally though it is simpler to use a single virtio-scsi PCI adapter
instead.

### virtio-scsi
The virtio-scsi device presents a SCSI Host Bus Adapter to the virtual machine.
SCSI offers a richer command set than virtio-blk and supports more use cases.

Each device supports up to 16,383 LUNs (disks) per target and up to 255
targets. This allows a single virtio-scsi device to handle all disks in a
virtual machine, although defining more virtio-scsi devices makes it possible
to tune for NUMA topology as we will see in a later blog post.

Emulated LUNs can be exposed as hard disk drives or CD-ROMs. Physical SCSI
devices can be passed through into the virtual machine, including CD-ROM
drives, tapes, and other devices besides hard disk drives.

Clustering software that uses SCSI Persistent Reservations is supported by virtio-scsi, but not by virtio-blk.

Performance of virtio-scsi may be lower than virtio-blk due to a thicker software stack, but in many use cases, this is not a significant factor. The following graph compares 4KB random read performance at various queue depths:

![Comparing virtio-blk and virtio-scsi performance](/screenshots/2020-09-15-virtio-blk-vs-scsi.svg)

### virtio-scsi configuration
The following SCSI devices are available with virtio-scsi:

|Device|SCSI Passthrough|Performance|
|------|----------------|-----------|
|scsi-hd|No|Highest|
|scsi-block|Yes|Lower|
|scsi-generic|Yes|Lowest|

The scsi-hd device is suitable for disk image files and host block devices
when SCSI passthrough is not required.

The scsi-block device offers SCSI passthrough and is preferred over
scsi-generic due to higher performance.

The following graph compares the sequential I/O performance of these devices
using virtio-scsi with an iothread:

![Comparing scsi-hd, scsi-block, and scsi-generic performance](/screenshots/2020-09-15-scsi-devices.svg)

## Conclusion
The virtio-blk and virtio-scsi offer a choice between a single block device and
a full-fledged SCSI Host Bus Adapter. Virtualized guests typically use one or
both of them depending on functional and performance requirements. This post
compared the two and offered recommendations on how to choose between them.

The next post in this series will discuss the iothreads feature that both
virtio-blk and virtio-scsi support for increased performance.
