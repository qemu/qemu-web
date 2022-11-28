---
layout: post
title:  "Introduction to Zoned Storage Emulation"
date:   2022-11-17
author: Sam Li
categories: [storage, gsoc, outreachy, internships]
---

This summer I worked on adding Zoned Block Device (ZBD) support to virtio-blk as part of the [Outreachy](https://www.outreachy.org/) internship program. QEMU hasn't directly supported ZBDs before so this article explains how they work and why QEMU needed to be extended.

## Zoned block devices

Zoned block devices (ZBDs) are divided into regions called zones that can only be written sequentially. By only allowing sequential writes, SSD write amplification can be reduced by eliminating the need for a [Flash Translation Layer](https://en.wikipedia.org/wiki/Flash_translation_layer), and potentially lead to higher throughput and increased capacity. Providing a new storage software stack, zoned storage concepts are standardized as [ZBC (SCSI standard), ZAC (ATA standard)](https://zonedstorage.io/docs/introduction/smr#governing-standards), and [ZNS (NVMe)](https://zonedstorage.io/docs/introduction/zns). Meanwhile, the virtio protocol for block devices(virtio-blk) should also be aware of ZBDs instead of taking them as regular block devices. It should be able to pass such devices through to the guest. An overview of necessary work is as follows:

1. Virtio protocol: [extend virtio-blk protocol with main zoned storage concept](https://lwn.net/Articles/914377/), Dmitry Fomichev
2. Linux: [implement the virtio specification extensions](https://www.spinics.net/lists/linux-block/msg91944.html), Dmitry Fomichev
3. QEMU: [add zoned storage APIs to the block layer](https://lists.gnu.org/archive/html/qemu-devel/2022-10/msg05195.html), Sam Li
4. QEMU: implement zoned storage support in virtio-blk emulation, Sam Li

Once the QEMU and Linux patches have been merged it will be possible to expose a virtio-blk ZBD to the guest like this:

```sh
-blockdev node-name=drive0,driver=zoned_host_device,filename=/path/to/zbd,cache.direct=on \
-device virtio-blk-pci,drive=drive0 \
```

And then we can perform zoned block commands on that device in the guest os.

```sh
# blkzone report /dev/vda
start: 0x000000000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 0(nw) [type: 1(CONVENTIONAL)]
start: 0x000020000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 0(nw) [type: 1(CONVENTIONAL)]
start: 0x000040000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 0(nw) [type: 1(CONVENTIONAL)]
start: 0x000060000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 0(nw) [type: 1(CONVENTIONAL)]
start: 0x000080000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 0(nw) [type: 1(CONVENTIONAL)]
start: 0x0000a0000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 0(nw) [type: 1(CONVENTIONAL)]
start: 0x0000c0000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 0(nw) [type: 1(CONVENTIONAL)]
start: 0x0000e0000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 0(nw) [type: 1(CONVENTIONAL)]
start: 0x000100000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 1(em) [type: 2(SEQ_WRITE_REQUIRED)]
start: 0x000120000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 1(em) [type: 2(SEQ_WRITE_REQUIRED)]
start: 0x000140000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 1(em) [type: 2(SEQ_WRITE_REQUIRED)]
start: 0x000160000, len 0x020000, cap 0x020000, wptr 0x000000 reset:0 non-seq:0, zcond: 1(em) [type: 2(SEQ_WRITE_REQUIRED)]
```

## Zoned emulation

Currently, QEMU can support zoned devices by virtio-scsi or PCI device passthrough. It needs to specify the device type it is talking to. Whereas storage controller emulation uses block layer APIs instead of directly accessing disk images. Extending virtio-blk emulation avoids code duplication and simplify the support by hiding the device types under a unified zoned storage interface, simplifying VM deployment for different types of zoned devices. Virtio-blk can also be implemented in hardware. If those devices wish to follow the zoned storage model then the virtio-blk specification needs to natively support zoned storage. With such support, individual NVMe namespaces or anything that is a zoned Linux block device can be exposed to the guest without passing through a full device.

For zoned storage emulation, zoned storage APIs support three zoned models (conventional, host-managed, host-aware) , four zone management commands (Report Zone, Open Zone, Close Zone, Finish Zone), and Append Zone.  The QEMU block layer has a BlockDriverState graph that propagates device information inside block layer. File-posix driver is the lowest level within the graph where zoned storage APIs reside.

After receiving the block driver states, Virtio-blk emulation recognizes zoned devices and sends the zoned feature bit to guest. Then the guest can see the zoned device in the host. When the guest executes zoned operations, virtio-blk driver issues corresponding requests that will be captured by viritio-blk device inside QEMU. Afterwards, virtio-blk device sends the requests to file-posix driver which will perform zoned operations using Linux ioctls.

Unlike zone management operations, Linux doesn't have a user API to issue zone append requests to zoned devices from user space. With the help of write pointer emulation tracking locations of write pointer of each zone, QEMU block layer can perform append writes by modifying regular writes. Write pointer locks guarantee the execution of requests. Upon failure it must not update the write pointer location which is only got updated when the request is successfully finished.

Problems can always be solved with right mind and right tools. A good approach to avoid pitfalls of programs is test-driven. In the beginning, users like qemu-io commands utility can invoke new block layer APIs. Moving towards to guest, existing tools like blktests, zonefs-tools, and fio are introduced for broader testing. Depending on the size of the zoned device, some tests may take long enough time to finish. Besides, tracing is also a good tool for spotting bugs. QEMU tracking tools and blktrace monitors block layer IO, providing detailed information to analysis.

## Starting the journey with open source

As a student interested in computer science, I am enthusiastic about making real applications and fortunate to find the opportunity in this summer. I have a wonderful experience with QEMU where I get chance to work with experienced engineers and meet peers sharing same interests. It is a good starting point for me to continue my search on storage systems and open source projects.

Public communication, reaching out to people and admitting to failures used to be hard for me. Those feelings had faded away as I put more effort to this project over time. For people may having the same trouble as me, it might be useful to focus on the tasks ahead of you instead of worrying about the consequences of rejections from others.

Finally, I would like to thank Stefan Hajnoczi, Damien Le Moal, Dmitry Fomichev, and Hannes Reinecke for mentoring me - they have guided me through this project with patience and expertise, when I hit  obstacles on design or implementations, and introduced a fun and vibrant open source world for me. Also thank QEMU community and Outreachy for organizing this program.

## Conclusion

The current status for this project is waiting for virtio specifications extension and Linux driver support patches got accepted. And the up-to-date patch series of zoned device support welcome any new comments.

The next step for zoned storage emulation in QEMU is to enable full zoned emulation through virtio-blk. Adding support on top of a regular file, it allows developers accessing a zoned device environment without real zoned storage hardwares. Furthermore, virtio-scsi may need to add full emulation support to complete the zoned storage picture in QEMU. QEMU NVMe ZNS emulation can also use new block layer APIs to attach real zoned storage if the emulation is used in production in future.
