---
layout: post
title:  "QEMU's new -nic command line option"
date:   2018-05-31 9:50:00 +0200
author: Thomas Huth
categories: [features, options, 'qemu 2.12']
---
If you used QEMU in the past, you are probably familiar with the `-net`
command line option, which can be used to configure a network connection
for the guest, or with with the `-netdev` option, which configures a network
back-end.  Yet, QEMU v2.12 introduces a third way to configure NICs, the
`-nic` option.

The [ChangeLog of QEMU
v2.12](https://wiki.qemu.org/ChangeLog/2.12#Network) says that `-nic`
can "quickly create a network front-end (emulated NIC) and a host
back-end".  But why did QEMU need yet another way to configure the
network, and how does it compare with `-net` and `-netdev`?  To answer
these questions, we need to look at the model behind network virtualization
in QEMU.

As hinted by the ChangeLog entry, a network interface consists of two
separate entities:

1. The emulated hardware that the guest sees, i.e. the so-called NIC (network
interface controller). On systems that support PCI cards, these typically
could be an e1000 network card, a rtl8139 network card or a virtio-net device.
This entity is also called the "front-end".

2. The network back-end on the host side, i.e. the interface that QEMU uses
to exchange network packets with the outside (like other QEMU instances
or other real hosts in your intranet or the internet). The common host
back-ends are the "user" (a.k.a. SLIRP) back-end which provides access to
the host's network via NAT, the "tap" back-end which allows the guest to
directly access the host's network, or the "socket" back-end which can be
used to connect multiple QEMU instances to simulate a shared network for
their guests.

Based on this, it is already possible to define the most obvious difference
between `-net`, `-netdev` and `-nic`: the `-net` option can create _either_
a front-end or a back-end (and also does other things); `-netdev` can only
create a back-end; while a single occurrence of `-nic` will create _both_ a
front-end and a back-end. But for the non-obvious differences, we also need
to have a detailed look at the `-net` and `-netdev` options first ...

The legacy -net option
----------------------

QEMU's initial way of configuring the network for the guest was the `-net`
option. The emulated NIC hardware can be chosen with the
`-net nic,model=xyz,...` parameter, and the host back-end with the
`-net <backend>,...` parameter (e.g. `-net user` for the SLIRP back-end).
However, the emulated NIC and the host back-end are not directly connected.
They are rather both connected to an emulated hub (called "vlan" in older
versions of QEMU). Therefore, if you start QEMU with `-net nic,model=e1000
-net user -net nic,model=virtio -net tap` for example, you get a setup where
all the front-ends and back-ends are connected together via a hub:

![Networking with -net](/screenshots/2018-05-31-qemu-cli-net.svg)

That means the e1000 NIC also gets the network traffic from the virtio-net
NIC and both host back-ends... this is probably not what the users expected;
it's more likely that they wanted two separate networks in the guest, one for
each NIC. Because `-net` always connects its NIC to a hub, you would have to
tell QEMU to use _two separate hubs_, using the "vlan" parameter. For example
`-net nic,model=e1000,vlan=0 -net user,vlan=0 -net nic,model=virtio,vlan=1
-net tap,vlan=1` moves the virtio-net NIC and the "tap" back-end to a second
hub (with ID #1).

Please note that the "vlan" parameter will be dropped in QEMU v3.0 since the term
was rather [confusing](https://bugs.launchpad.net/qemu/+bug/658904) (it's not
related to IEEE 802.1Q for example) and caused a lot of misconfigurations in
the past. Additional hubs can still be instantiated with `-netdev` (or `-nic`)
and the special "hubport" back-end. The `-net` option itself will still stay
around since it is still useful if you only want to use one front-end and
one back-end together, or if you want to tunnel the traffic of multiple
NICs through one back-end only (something like `-net nic,model=e1000
-net nic,model=virtio -net l2tpv3,...` for example).


The modern -netdev option
-------------------------

Beside the confusing "vlan" parameter of the `-net` option, there is one more
major drawback with `-net`: the emulated hub between the NIC and the
back-end gets in the way when the NIC front-end has to work closely together
with the host back-end. For example, vhost acceleration cannot be enabled
if you create a virtio-net device with `-net nic,model=virtio`.

To configure a network connection where the emulated NIC is directly connected
to a host network back-end, without a hub in between, the well-established
solution is to use the `-netdev` option for the back-end, together with
`-device` for the front-end. Assuming that you want to configure the same
devices as in the `-net` example above, you could use `-netdev user,id=n1
-device e1000,netdev=n1 -netdev tap,id=n2 -device virtio-net,netdev=n2`.
This will give you straight 1:1 connections between the NICs and the host
back-ends:

![Networking with -netdev](/screenshots/2018-05-31-qemu-cli-netdev.svg)

Note that you can also still connect the devices to a hub with the special
`-netdev hubport` back-end, but in most of the normal use cases, the use
of a hub is not required anymore.

Now while `-netdev` together with `-device` provide a very flexible and
extensive way to configure a network connection, there are still two
drawbacks with this option pair which prevented us from deprecating the
legacy `-net` option completely:

1. The `-device` option can only be used for pluggable NICs. Boards
(e.g. embedded boards) which feature an on-board NIC cannot be configured
with `-device` yet, so `-net nic,netdev=<id>` must be used here instead.

2. In some cases, the `-net` option is easier to use (less to type).
For example, assuming you want to set up a "tap" network connection and
your default scripts /etc/qemu-ifup and -down are already in place,
it's enough to type `-net nic -net tap` to start your guest. To do the
same with `-netdev`, you always have to specify an ID here, too, for
example like this: `-netdev tap,id=n1 -device e1000,netdev=n1`.

The new -nic option
-------------------

Looking at the disadvantages listed above, users could benefit from a
convenience option that:

 * is easier to use (and shorter to type) than `-netdev <backend>,id=<id>
  -device <dev>,netdev=<id>`
 * can be used to configure on-board / non-pluggable NICs, too
 * does not place a hub between the NIC and the host back-end.

This is where the new `-nic` option kicks in: this option can be used
to configure both the guest's NIC hardware and the host back-end in
one go. For example, instead of `-netdev tap,id=n1 -device e1000,netdev=n1`
you can simply type `-nic tap,model=e1000`. If you don't care about the
exact NIC model type, you can even omit the `model=...` parameter and type
`-nic tap`. This is even shorter and more convenient than the previous
shortest way of typing `-net nic -net tap`. To get a list of NIC models
that you can use with this option, you can simply run QEMU with
`-nic model=help`.

Beside being easier to use, the `-nic` option can be used to configure
on-board NICs, too (just like the `-net` option). For machines that have
on-board NICs, the first `-nic` option configures the first on-board NIC,
the second `-nic` option configures the second on-board NIC, and so forth.

Conclusion
----------

 * The new `-nic` option gives you an easy and quick way to configure
   the networking of your guest.
 * For more detailed configuration, e.g. when you need to tweak the details
   of the emulated NIC hardware, you can use `-device` together with `-netdev`.
 * The `-net` option should be avoided these days unless you really want to
   configure a set-up with a hub between the front-ends and back-ends.
