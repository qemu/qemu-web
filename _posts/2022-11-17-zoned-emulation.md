---
layout: post
title:  "Introduction to Zoned Storage Emulation"
date:   2022-11-17
author: Sam Li
categories: [storage, gsoc, outreachy, internships]
---

## Zoned block devices

Aimed for at-scale data infrastructures, zoned block devices (ZBDs) divide the LBA space into block regions called zones that are larger than the LBA size. By only allowing sequential writes, it can reduce write amplification in SSDs, and potentially lead to higher throughput and increased capacity. Providing new storage software stack, zoned storage concept is standardized as ZBC(SCSI standard), ZAC(ATA standard), ZNS(NVMe). Meanwhile, the virtio protocol for block devices(virtio-blk) should also be aware of ZBDs instead of taking them as regular block devices. It should be able to pass such devices through to the guest. An overview of necessary work is as follows:

1. Virtio protocol: [extend virtio-blk protocol with main zoned storage concept](https://lwn.net/Articles/914377/), Dmitry Fomichev
2. Linux: [implement the virtio specification extensions](https://www.spinics.net/lists/linux-block/msg91944.html), Dmitry Fomichev
3. QEMU: add zoned emulation support to virtio-blk, Sam Li, [Outreachy 2022 project](https://wiki.qemu.org/Internships/ProjectIdeas/VirtIOBlkZonedBlockDevices)

<img src="/screenshots/zbd.png" alt="zbd" style="zoom:50%;" />

## Zoned emulation

Currently, QEMU can support zoned devices by virtio-scsi or PCI device passthrough. It needs to specify the device type it is talking to. While storage controller emulation uses block layer APIs instead of directly accessing disk images. Extending virtio-blk emulation avoids code duplication and simplify the support by hiding the device types under a unified zoned storage interface, simplifying VM deployment for different type of zoned devices.

For zoned storage emulation, zoned storage APIs support three zoned models(conventional, host-managed, host-aware) , four zone management commands(Report Zone, Open Zone, Close Zone, Finish Zone), and Append Zone.  QEMU block storage has a BlockDriverState graph that propagates device information inside block layer. A root pointer at BlockBackend points to the graph. There are three type of block driver nodes: filter node, format node, protocol node. File-posix driver is the lowest level within the graph where zoned storage APIs reside.

<img src="/screenshots/storage_overview.png" alt="storage_overview" style="zoom: 50%;" />

After receiving the block driver states, Virtio-blk emulation recognizes zoned devices and sends the zoned feature bit to guest. Then the guest can see the zoned device in the host. When the guest executes zoned operations, virtio-blk driver issues corresponding requests that will be captured by virito-blk device inside QEMU. Afterwards, virtio-blk device sends the requests to file-posix driver which will perform zoned operations.

Unlike zone management operations, Linux doesn't have a user API to issue zone append requests to zoned devices from user space. With the help of write pointer emulation tracking locations of write pointer of each zone, QEMU block layer performs append writes by modifying regular writes. Write pointer locks guarantee the execution of requests. Upon failure it must not update the write pointer location which is only got updated when the request is successfully finished.

Problems can always be sovled with right mind and right tools. A good approach to avoid pitfalls of program is test-driven. In the beginning, users like qemu-io commands utility can invoke new block layer APIs. Moving towards to guest, existing tools like blktests, zonefs-tools, and fio can be introduced for broader testing. Depending on the size of the zoned device, some tests may take long enough time to finish. Besides, tracing is good for spotting bugs. QEMU tracking tools and blktrace monitors block layer IO, providing detailed information to analysis.

## Starting the journey with open source

As a student interested in computer science engineering, I am enthusiastic about making real applications and fortunate to find the opportunity in this summer. I have a wonderful experience with QEMU where I get chance to work with experienced engineers and meet peers sharing same interests. It is a good starting point for me to continue my search on storage systems and open source projects. 

Public communication, reaching out to people and admitting to failures used to be hard for me. Those feelings had faded away as I put more effort to this project over time. For people may having the same trouble as me, it might be useful to focus on what task ahead of you instead of worrying about the consequences of rejections from others. 

Finally, I would like to thank Stefan Hajnoczi, Damien Le Moal, Dmitry Fomichev, and Hannes Reinecke for mentoring me - they have guided me through this project when I hit  obstacles on design or implementations and introduced a fun and vibrant open source world for me. Also thank QEMU community and Outreachy for organizing this program.

## Conclusion

The current status for this project is waiting for virtio specifications extension and Linux driver support patches got accepted. And the up-to-data patch series of zoned device support welcome any new comments.

The next step for zoned storage emulation in QEMU is to enable full zoned emulation through virtio-blk. Adding support on top of a regular file, it allows developers accessing a zoned device environment without real zoned storage hardwares. Furthermore, virtio-scsi may need to add full emulation support to complete the zoned storage picture in QEMU. QEMU NVMe ZNS emulation can also use new block layer APIs to attach real zoned storage if the emulation is used in production in future.
