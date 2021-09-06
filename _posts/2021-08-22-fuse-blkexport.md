---
layout: post
title:  "Presenting guest images as raw image files with FUSE"
date:   2021-08-22 14:00:00 +0200
last_modified_at: 2021-09-06 18:30:00:00 +0200
author: Hanna Reitz
categories: [storage, features, tutorials]
---
Sometimes, there is a VM disk image whose contents you want to manipulate
without booting the VM.  One way of doing this is to use
[libguestfs](https://libguestfs.org), which can boot a minimal Linux VM to
provide the host with secure access to the disk’s contents.  For example,
[*guestmount*](https://libguestfs.org/guestmount.1.html) allows you to mount a
guest filesystem on the host, without requiring root rights.

However, maybe you cannot or do not want to use libguestfs, e.g. because you do
not have KVM available in your environment, and so it becomes too slow; or
because you do not want to go through a guest OS, but want to access the raw
image data directly on the host, with minimal overhead.

**Note**: Guest images can generally be arbitrarily modified by VM guests.  If
you have an image to which an untrusted guest had write access at some point,
you must treat any data and metadata on this image as potentially having been
modified in a malicious manner.  Parsing anything must be done carefully and
with caution.  Note that many existing tools are not careful in this regard, for
example, filesystem drivers generally deliberately do not have protection
against maliciously corrupted filesystems.  This is why in contrast accessing an
image through libguestfs is considered secure, because the actual access happens
in a libvirt-managed VM guest.

From this point, we assume you are aware of the security caveats and still want
to access and manipulate image data on the host.

Now, unless your image is already in raw format, you will be faced with the
problem of getting it into raw format.  The tools that you might want to use for
image manipulation generally only work on raw images (because that is how block
device files appear), like:
* *dd* to just copy data to and from given offsets,
* *parted* to manipulate the partition table,
* *kpartx* to present all partitions as block devices,
* *mount* to access filesystems’ contents.

So if you want to use such tools on image files e.g. in QEMU’s qcow2 format, you
will need to translate them into raw images first, for example by:
* Exporting the image file with `qemu-nbd -c` as an NBD block device file,
* Converting between image formats using `qemu-img convert`,
* Accessing the image from a guest, where it appears as a normal block device.

Unfortunately, none of these methods is perfect: `qemu-nbd -c` generally
requires root rights; converting to a temporary raw copy requires additional
disk space and the conversion process takes time; and accessing the image from a
guest is basically what libguestfs does (i.e., if that is what you want, then
you should probably use libguestfs).

As of QEMU 6.0, there is another method, namely FUSE block exports.
Conceptually, these are rather similar to using `qemu-nbd -c`, but they do not
require root rights.

**Note**: FUSE block exports are a feature that can be enabled or disabled
during the build process with `--enable-fuse` or `--disable-fuse`, respectively;
omitting either configure option will enable the feature if and only if libfuse3
is present.  It is possible that the QEMU build you are using does not have FUSE
block export support, because it was not compiled in.

FUSE (*Filesystem in Userspace*) is a technology to let userspace processes
provide filesystem drivers.  For example, *sshfs* is a program that allows
mounting remote directories from a machine accessible via SSH.

QEMU can use FUSE to make a virtual block device appear as a normal file on the
host, so that tools like *kpartx* can interact with it regardless of the image
format, like in the following example:

```
$ qemu-img create -f raw foo.img 20G
Formatting 'foo.img', fmt=raw size=21474836480

$ parted -s foo.img \
    'mklabel msdos' \
    'mkpart primary ext4 2048s 100%'

$ qemu-img convert -p -f raw -O qcow2 foo.img foo.qcow2 && rm foo.img
    (100.00/100%)

$ file foo.qcow2
foo.qcow2: QEMU QCOW2 Image (v3), 21474836480 bytes

$ sudo kpartx -l foo.qcow2

$ qemu-storage-daemon \
    --blockdev node-name=prot-node,driver=file,filename=foo.qcow2 \
    --blockdev node-name=fmt-node,driver=qcow2,file=prot-node \
    --export \
    type=fuse,id=exp0,node-name=fmt-node,mountpoint=foo.qcow2,writable=on \
    &
[1] 200495

$ file foo.qcow2
foo.qcow2: DOS/MBR boot sector; partition 1 : ID=0x83, start-CHS (0x10,0,1),
end-CHS (0x3ff,3,32), startsector 2048, 41940992 sectors

$ sudo kpartx -av foo.qcow2
add map loop0p1 (254:0): 0 41940992 linear 7:0 2048
```

In this example, we create a partition on a newly created raw image.  We then
convert this raw image to qcow2 and discard the original.  Because a tool like
*kpartx* cannot parse the qcow2 format, it reports no partitions to be present
in `foo.qcow2`.

Using the QEMU storage daemon, we then create a FUSE export for the image that
apparently turns it into a raw image, which makes the content and thus the
partitions visible to *file* and *kpartx*.  Now, we can use *kpartx* to access
the partition in `foo.qcow2` under `/dev/mapper/loop0p1`.

So how does this work?  How can the QEMU storage daemon make a qcow2 image
appear as a raw image?

## File mounts

To transparently translate a file into a different format, like we did above, we
make use of two little-known facts about filesystems and the VFS on Linux.  The
first one of these we can explain immediately, for the second one we will need
some more information about how FUSE exports work, so that secret will be lifted
later (down in the “Mounting an image on itself” section).

Here is the first secret: Filesystems do not need to have a root directory.
They only need a root node.  A regular file is a node, so a filesystem that only
consists of a single regular file is perfectly valid.

Note that this is not about filesystems with just a single file in their root
directory, but about filesystems that really *do not have* a root directory.

Conceptually, every filesystem is a tree, and mounting works by replacing one
subtree of the global VFS tree by the mounted filesystem’s tree.  Normally, a
filesystem’s root node is a directory, like in the following example:

|![Regular filesystem: Root directory is mounted to a directory mount point](/screenshots/2021-08-18-root-directory.svg)|
|:--:|
|*Fig. 1: Mounting a regular filesystem with a directory as its root node*|

Here, the directory `/foo` and its content (the files `/foo/a` and `/foo/b`) are
shadowed by the new filesystem (showing `/foo/x` and `/foo/y`).

Note that a filesystem’s root node generally has no name.  After mounting, the
filesystem’s root directory’s name is determined by the original name of the
mount point.  (“/” is not a name.  It specifically is a directory without a
name.)

Because a tree does not need to have multiple nodes but may consist of just a
single leaf, a filesystem with a file for its root node works just as well,
though:

|![Mounting a file root node to a regular file mount point](/screenshots/2021-08-18-root-file.svg)|
|:--:|
|*Fig. 2: Mounting a filesystem with a regular (unnamed) file as its root node*|

Here, FS B only consists of a single node, a regular file with no name.  (As
above, a filesystem’s root node is generally unnamed.) Consequently, the mount
point for it must also be a regular file (`/foo/a` in our example), and just
like before, the content of `/foo/a` is shadowed, and when opening it, one will
instead see the contents of FS B’s unnamed root node.

## QEMU block exports

Before we can see what FUSE exports are and how they work, we should explore
QEMU block exports in general.

QEMU allows exporting block nodes via various protocols (as of 6.0: NBD,
vhost-user, FUSE).  A block node is an element of QEMU’s block graph (see e.g.
[Managing the New Block Layer](http://events17.linuxfoundation.org/sites/events/files/slides/talk\_11.pdf),
a talk given at KVM Forum 2017), which can for example be attached to guest
devices.  Here is a very simple example:

|![Block graph: image file <-> file node (label: prot-node) <-> qcow2 node (label: fmt-node) <-> virtio-blk guest device](/screenshots/2021-08-18-block-graph-a.svg)|
|:--:|
|*Fig. 3: A simple block graph for attaching a qcow2 image to a virtio-blk guest device*|

This is the simplest example for a block graph that connects a *virtio-blk*
guest device to a qcow2 image file.  The *file* block driver, instanced in the
form of a block node named *prot-node*, accesses the actual file and provides
the node above it access to the raw content.  This node above, named *fmt-node*,
is handled by the *qcow2* block driver, which is capable of interpreting the
qcow2 format.  Parents of this node will therefore see the actual content of the
virtual disk that is represented by the qcow2 image.  There is only one parent
here, which is the *virtio-blk* guest device, which will thus see the virtual
disk.

The command line to achieve the above could look something like this:
```
$ qemu-system-x86_64 \
    -blockdev node-name=prot-node,driver=file,filename=$image_path \
    -blockdev node-name=fmt-node,driver=qcow2,file=prot-node \
    -device virtio-blk,drive=fmt-node,share-rw=on
```

Besides attaching guest devices to block nodes, you can also export them for
users outside of qemu, for example via NBD.  Say you have a QMP channel open for
the QEMU instance above, then you could do this:
```json
{
    "execute": "nbd-server-start",
    "arguments": {
        "addr": {
            "type": "inet",
            "data": {
                "host": "localhost",
                "port": "10809"
            }
        }
    }
}
{
    "execute": "block-export-add",
    "arguments": {
        "type": "nbd",
        "id": "exp0",
        "node-name": "fmt-node",
        "name": "guest-disk",
        "writable": true
    }
}
```

This opens an NBD server on `localhost:10809`, which exports *fmt-node* (under
the NBD export name *guest-disk*).  The block graph looks as follows:

|![Same block graph as fig. 3, but with an NBD server attached to fmt-node](/screenshots/2021-08-18-block-graph-b.svg)|
|:--:|
|*Fig. 4: Block graph extended by an NBD server*|

NBD clients connecting to this server will see the raw disk as seen by the
guest – we have *exported* the guest disk:

```
$ qemu-img info nbd://localhost/guest-disk
image: nbd://localhost:10809/guest-disk
file format: raw
virtual size: 20 GiB (21474836480 bytes)
disk size: unavailable
```

### QEMU storage daemon

If you are not running a guest, and so do not need guest devices, but all you
want is to use the QEMU block layer (for example to interpret the qcow2 format)
and export nodes from the block graph, then you can use the more lightweight
QEMU storage daemon instead of a full-blown QEMU process:

```
$ qemu-storage-daemon \
    --blockdev node-name=prot-node,driver=file,filename=$image_path \
    --blockdev node-name=fmt-node,driver=qcow2,file=prot-node \
    --nbd-server addr.type=inet,addr.host=localhost,addr.port=10809 \
    --export \
    type=nbd,id=exp0,node-name=fmt-node,name=guest-disk,writable=on
```

Which creates the following block graph:

|![Block graph: image file <-> file node (label: prot-node) <-> qcow2 node (label: fmt-node) <-> NBD server](/screenshots/2021-08-18-block-graph-c.svg)|
|:--:|
|*Fig. 5: Exporting a qcow2 image over NBD*|

## FUSE block exports

Besides NBD exports, QEMU also supports vhost-user and FUSE exports.  FUSE block
exports make QEMU become a FUSE driver that provides a filesystem that consists
of only a single node, namely a regular file that has the raw contents of the
exported block node.  QEMU will automatically mount this filesystem on a given
existing regular file (which acts as the mount point, as described in the
“File mounts” section).

Thus, FUSE exports can be used like this:

```
$ touch mount-point

$ qemu-storage-daemon \
  --blockdev node-name=prot-node,driver=file,filename=$image_path \
  --blockdev node-name=fmt-node,driver=qcow2,file=prot-node \
  --export \
  type=fuse,id=exp0,node-name=fmt-node,mountpoint=mount-point,writable=on
```

The mount point now appears as the raw VM disk that is stored in the qcow2
image:
```
$ qemu-img info mount-point
image: mount-point
file format: raw
virtual size: 20 GiB (21474836480 bytes)
disk size: 196 KiB
```

And *mount* tells us that this is indeed its own filesystem:
```
$ mount | grep mount-point
/dev/fuse on /tmp/mount-point type fuse (rw,nosuid,nodev,relatime,user_id=1000,
group_id=100,default_permissions,allow_other,max_read=67108864)
```

The block graph looks like this:

|![Block graph: image file <-> file node (label: prot-node) <-> qcow2 node (label: fmt-node) <-> FUSE server <-> exported file](/screenshots/2021-08-18-block-graph-d.svg)|
|:--:|
|*Fig. 6: Exporting a qcow2 image over FUSE*|

Closing the storage daemon (e.g. with Ctrl-C) automatically unmounts the export,
turning the mount point back into an empty normal file:

```
$ mount | grep -c mount-point
0

$ qemu-img info mount-point
image: mount-point
file format: raw
virtual size: 0 B (0 bytes)
disk size: 0 B
```

## Mounting an image on itself

So far, we have seen what FUSE exports are, how they work, and how they can be
used.  However, in the very first example in this blog post, we did not export
the raw image on some empty regular file that just serves as a mount point – no,
we turned the original qcow2 image itself into a raw image.

How does that work?

### What happens to the old tree under a mount point?

Mounting a filesystem only shadows the mount point’s original content, it does
not remove it.  The original content can no longer be looked up via its
(absolute) path, but it is still there, much like a file that has been unlinked
but is still open in some process.  Here is an example:

First, create some file in some directory, and have some process keep it open:

```
$ mkdir foo

$ echo 'Is anyone there?' > foo/bar

$ irb
irb(main):001:0> f = File.open('foo/bar', 'r+')
=> #<File:foo/bar>
irb(main):002:0> ^Z
[1]  + 35494 suspended  irb
```

Next, mount something on the directory:

```
$ sudo mount -t tmpfs tmpfs foo
```

The file cannot be found anymore (because *foo*’s content is shadowed by the
mounted filesystem), but the process who kept it open can still read from it,
and write to it:
```
$ ls foo

$ cat foo/bar
cat: foo/bar: No such file or directory

$ fg
f.read
irb(main):002:0> f.read
=> "Is anyone there?\n"
irb(main):003:0> f.puts('Hello from the shadows!')
=> nil
irb(main):004:0> exit

$ ls foo

$ cat foo/bar
cat: foo/bar: No such file or directory
```

Unmounting the filesystem lets us see our file again, with its updated content:
```
$ sudo umount foo

$ ls foo
bar

$ cat foo/bar
Is anyone there?
Hello from the shadows!
```

### Letting a FUSE export shadow its image file

The same principle applies to file mounts: The original inode is shadowed (along
with its content), but it is still there for any process that opened it before
the mount occurred.  Because QEMU (or the storage daemon) opens the image file
before mounting the FUSE export, you can therefore specify an image’s path as
the mount point for its corresponding export:

```
$ qemu-img create -f qcow2 foo.qcow2 20G
Formatting 'foo.qcow2', fmt=qcow2 cluster_size=65536 extended_l2=off
 compression_type=zlib size=21474836480 lazy_refcounts=off refcount_bits=16

$ qemu-img info foo.qcow2
image: foo.qcow2
file format: qcow2
virtual size: 20 GiB (21474836480 bytes)
disk size: 196 KiB
cluster_size: 65536
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false

$ qemu-storage-daemon --blockdev \
   node-name=node0,driver=qcow2,file.driver=file,file.filename=foo.qcow2 \
   --export \
   type=fuse,id=node0-export,node-name=node0,mountpoint=foo.qcow2,writable=on &
[1] 40843

$ qemu-img info foo.qcow2
image: foo.qcow2
file format: raw
virtual size: 20 GiB (21474836480 bytes)
disk size: 196 KiB

$ kill %1
[1]  + 40843 done       qemu-storage-daemon --blockdev  --export
```

In graph form, that looks like this:

|![Two graphs: First, foo.qcow2 is opened by QEMU; second, a FUSE server exports the raw disk under foo.qcow2, thus shadowing the original foo.qcow2](/screenshots/2021-08-18-block-graph-e.svg)|
|:--:|
|*Fig. 6: Exporting a qcow2 image via FUSE on its own path*|

QEMU (or the storage daemon in this case) keeps the original (qcow2) file open,
and so it keeps access to it, even after the mount.  However, any other process
that opens the image by name (i.e. `open("foo.qcow2")`) will open the raw disk
image exported by QEMU.  Therefore, it looks like the qcow2 image is in raw
format now.

### *qemu-fuse-disk-export.py*

Because the QEMU storage daemon command line tends to become kind of long, I’ve
written a script to facilitate the process:
[*qemu-fuse-disk-export.py*](https://gitlab.com/hreitz/qemu-scripts/-/blob/main/qemu-fuse-disk-export.py)
([direct download link](https://gitlab.com/hreitz/qemu-scripts/-/raw/main/qemu-fuse-disk-export.py?inline=false)).
This script automatically detects the image format, and its `--daemonize` option
allows safe use in scripts, where it is important that the process blocks until
the export is fully set up.

Using *qemu-fuse-disk-export.py*, the above example looks like this:
```
$ qemu-img info foo.qcow2 | grep 'file format'
file format: qcow2

$ qemu-fuse-disk-export.py foo.qcow2 &
[1] 13339
All exports set up, ^C to revert

$ qemu-img info foo.qcow2 | grep 'file format'
file format: raw

$ kill -SIGINT %1
[1]  + 13339 done       qemu-fuse-disk-export.py foo.qcow2

$ qemu-img info foo.qcow2 | grep 'file format'
file format: qcow2
```

Or, with `--daemonize`/`-d`:
```
$ qemu-img info foo.qcow2 | grep 'file format'
file format: qcow2

$ qemu-fuse-disk-export.py -dp qfde.pid foo.qcow2

$ qemu-img info foo.qcow2 | grep 'file format'
file format: raw

$ kill -SIGINT $(cat qfde.pid)

$ qemu-img info foo.qcow2 | grep 'file format'
file format: qcow2
```

## Bringing it all together

Now we know how to make disk images in any format understood by QEMU appear as
raw images.  We can thus run any application on them that works with such raw
disk images:

```
$ qemu-fuse-disk-export.py \
    -dp qfde.pid \
    Arch-Linux-x86_64-basic-20210711.28787.qcow2

$ parted Arch-Linux-x86_64-basic-20210711.28787.qcow2 p
WARNING: You are not superuser.  Watch out for permissions.
Model:  (file)
Disk /tmp/Arch-Linux-x86_64-basic-20210711.28787.qcow2: 42.9GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size    File system  Name  Flags
 1      1049kB  2097kB  1049kB                     bios_grub
 2      2097kB  42.9GB  42.9GB  btrfs

$ sudo kpartx -av Arch-Linux-x86_64-basic-20210711.28787.qcow2
add map loop0p1 (254:0): 0 2048 linear 7:0 2048
add map loop0p2 (254:1): 0 83881951 linear 7:0 4096

$ sudo mount /dev/mapper/loop0p2 /mnt/tmp

$ ls /mnt/tmp
bin   boot  dev  etc  home  lib  lib64  mnt  opt  proc  root  run  sbin  srv
swap  sys   tmp  usr  var

$ echo 'Hello, qcow2 image!' > /mnt/tmp/home/arch/hello

$ sudo umount /mnt/tmp

$ sudo kpartx -d Arch-Linux-x86_64-basic-20210711.28787.qcow2
loop deleted : /dev/loop0

$ kill -SIGINT $(cat qfde.pid)
```

And launching the image, in the guest we see:
```
[arch@archlinux ~] cat hello
Hello, qcow2 image!
```

## A note on `allow_other`

In the example presented in the above section, we access the exported image with
a different user than the one who exported it (to be specific, we export it as a
normal user, and then access it as root).  This does not work prior to QEMU 6.1:

```
$ qemu-fuse-disk-export.py -dp qfde.pid foo.qcow2

$ sudo stat foo.qcow2
stat: cannot statx 'foo.qcow2': Permission denied
```

QEMU 6.1 has introduced support for FUSE’s `allow_other` mount option.  Without
that option, only the user who exported the image has access to it.  By default,
if the system allows for non-root users to add `allow_other` to FUSE mount
options, QEMU will add it, and otherwise omit it.  It does so by simply
attempting to mount the export with `allow_other` first, and if that fails, it
will try again without.  (You can also force the behavior with the
`allow_other=(on|off|auto)` export parameter.)

Non-root users can pass `allow_other` if and only if `/etc/fuse.conf` contains
the `user_allow_other` option.

## Conclusion

As shown in this blog post, FUSE block exports are a relatively simple way to
access images in any format understood by QEMU as if they were raw images.
Any tool that can manipulate raw disk images can thus manipulate images in any
format, simply by having the QEMU storage daemon provide a translation layer.
By mounting the FUSE export on the original image path, this translation layer
will effectively be invisible, and the original image will look like it is in
raw format, so it can directly be accessed by those tools.

The current main disadvantage of FUSE exports is that they offer relatively bad
performance.  That should be fine as long as your use case is just light
manipulation of some VM images, like manually modifying some files on them.
However, we did not yet really try to optimize performance, so if more serious
use cases appear that would require better performance, we can try.
