---
layout: post
title:  "An Overview of QEMU Storage Features"
date:   2020-09-14 07:00:00 +0000
categories: [storage]
---
This article introduces QEMU storage concepts including disk images, emulated
storage controllers, block jobs, the qemu-img utility, and qemu-storage-daemon.
If you are new to QEMU or want an overview of storage functionality in QEMU
then this article explains how things fit together.

## Storage technologies
Persistently storing data and retrieving it later is the job of storage devices
such as hard disks, solid state drives (SSDs), USB flash drives, network
attached storage, and many others. Technologies vary in their storage capacity
(disk size), access speed, price, and other factors but most of them follow the
same block device model.

![Block device I/O](/screenshots/2020-09-14-block-device-io.svg)

Block devices are accessed in storage units called blocks. It is not possible
to access individual bytes, instead an entire block must be transferred. Block
sizes vary between devices with 512 bytes and 4KB block sizes being the most
common.

As an emulator and virtualizer of computer systems, QEMU naturally has to offer
block device functionality. QEMU is capable of emulating hard disks, solid
state drives (SSDs), USB flash drives, SD cards, and more.

## Storage for virtual machines
There is more to storage than just persisting data on behalf of a virtual
machine. The lifecycle of a disk image includes several operations that are
briefly covered below.

![Block device I/O](/screenshots/2020-09-14-lifecycle.svg)

Virtual machines consist of device configuration (how much RAM, which
graphics card, etc) and the contents of their disks. Transferring virtual
machines either to migrate them between hosts or to distribute them to users is
an important workflow that QEMU and its utilities support.

Much like ISO files are used to distribute operating system installer images,
QEMU supports disk image file formats that are more convenient for transferring
disk images than the raw contents of a disk. In fact, disk image file formats
offer many other features such as the ability to import/export disks from other
hypervisors, snapshots, and instantiating new disk images from a backing file.

Finally, managing disk images also involves the ability to take backups and
restore them should it be necessary to roll back after the current disk
contents have been lost or corrupted.

## Emulated storage controllers

The virtual machine accesses block devices through storage controllers. These
are the devices that the guest talks to in order to read or write blocks. Some
storage controllers facilitate access to multiple block devices, such as a SCSI
Host Bus Adapter that provides access to many SCSI disks.

Storage controllers vary in their features, performance, and guest operating
system support. They expose a storage interface such as virtio-blk, NVMe, or
SCSI. Virtual machines program storage controller registers to transfer data
between memory buffers in RAM and block devices. Modern storage controllers
support multiple request queues so that I/O can processed in parallel at high
rates.

The most common storage controllers in QEMU are virtio-blk, virtio-scsi, AHCI
(SATA), IDE for legacy systems, and SD Card controllers on embedded or smaller
boards.

## Disk image file formats

Disk image file formats handle the layout of blocks within a host file or
device. The simplest format is the raw format where each block is located at
its Logical Block Address (LBA) in the host file. This simple scheme does not
offer much in the way of features.

QEMU's native disk image format is QCOW2 and it offers a number of features:
* Compactness - the host file grows as blocks are written so a sparse disk image can be much smaller than the virtual disk size.
* Backing files - disk images can be based on a parent image so that a master image can be shared by virtual machines.
* Snapshots - the state of the disk image can be saved and later reverted.
* Compression - block compression reduces the image size.
* Encryption - the disk image can be encrypted to protect data at rest.
* Dirty bitmaps - backup applications can track changed blocks so that efficient incremental backups are possible.

A number of other disk image file formats are available for importing/exporting
disk images for use with other software including VMware and Hyper-V.

## Block jobs

Block jobs are background operations that manipulate disk images:
* Commit - merging backing files to shorten a backing file chain.
* Backup - copying out a point-in-time snapshot of a disk.
* Mirror - copying an image to a new destination while the virtual machine can still write to it.
* Stream - populating a disk image from its backing file.
* Create - creating new disk image files.

These background operations are powerful tools for building storage migration
and backup workflows.

Some operations like mirror and stream can take a long time because they copy
large amounts of data. Block jobs support throttling to limit the performance
impact on virtual machines.

## qemu-img and qemu-storage-daemon

The [qemu-img utility](https://www.qemu.org/docs/master/interop/qemu-img.html) manipulates disk images. It can create, resize, snapshot,
repair, and inspect disk images. It has both human-friendly and JSON output
formats, making it suitable for manual use as well as scripting.

qemu-storage-daemon exposes QEMU's storage functionality in a server process
without running a virtual machine. It can export disk images over the Network
Block Device (NBD) protocol as well as run block jobs and other storage
commands. This makes qemu-storage-daemon useful for applications that want to
automate disk image manipulation.

## Conclusion

QEMU presents block devices to virtual machines via emulated storage
controllers. On the host side the disk image file format, block jobs, and
qemu-img/qemu-storage-daemon utilities provide functionality for working with
disk images. Future blog posts will dive deeper into some of these areas and
describe best practices for configuring storage.
