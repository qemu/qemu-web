---
title: Security Process
permalink: /contribute/security-process/
---

QEMU takes security very seriously, and we aim to take immediate action to
address serious security-related problems that involve our product.

Please report any suspected security vulnerability in QEMU to the following
addresses. You can use GPG keys for respective receipients to communicate with
us securely. If you do, please upload your GPG public key or supply it to us
in some other way, so that we can communicate to you in a secure way, too!
Please include the tag **\[QEMU-SECURITY\]** on the subject line to help us
identify your message as security-related. 

## QEMU Security Contact List

Please copy everyone on this list:

 Contact Person(s)	| Contact Address		| Company	|  GPG Key  | GPG key fingerprint
:-----------------------|:------------------------------|:--------------|:---------:|:--------------------
 Michael S. Tsirkin	| mst@redhat.com		| Red Hat Inc.	| [&#x1f511;](https://pgp.mit.edu/pks/lookup?op=vindex&search=0xC3503912AFBE8E67) | 0270 606B 6F3C DF3D 0B17 0970 C350 3912 AFBE 8E67
 Petr Matousek		| pmatouse@redhat.com		| Red Hat Inc.	| [&#x1f511;](https://pgp.mit.edu/pks/lookup?op=vindex&search=0x3E786F42C44977CA) | 8107 AF16 A416 F9AF 18F3 D874 3E78 6F42 C449 77CA
 Stefano Stabellini	| sstabellini@kernel.org 	| Independent	| [&#x1f511;](https://pgp.mit.edu/pks/lookup?op=vindex&search=0x894F8F4870E1AE90) | D04E 33AB A51F 67BA 07D3 0AEA 894F 8F48 70E1 AE90
 Security Response Team | secalert@redhat.com		| Red Hat Inc.	| [&#x1f511;](https://access.redhat.com/site/security/team/contact/#contact) |
 Michael Roth		| mdroth@linux.vnet.ibm.com	| IBM		| [&#x1f511;](https://pgp.mit.edu/pks/lookup?op=vindex&search=0x3353C9CEF108B584) | CEAC C9E1 5534 EBAB B82D 3FA0 3353 C9CE F108 B584
 Prasad J Pandit 	| pjp@redhat.com		| Red Hat Inc.	| [&#x1f511;](http://pool.sks-keyservers.net/pks/lookup?op=vindex&search=0xE2858B5AF050DE8D) | 8685 545E B54C 486B C6EB 271E E285 8B5A F050 DE8D 

## How to Contact Us Securely

We use GNU Privacy Guard (GnuPG or GPG) keys to secure communications. Mail
sent to members of the list can be encrypted with public keys of all members
of the list. We expect to change some of the keys we use from time to time.
Should a key change, the previous one will be revoked.

## How we respond

Maintainers listed on the security reporting list operate a policy of
responsible disclosure. As such they agree that any information you share with
them about security issues that are not public knowledge is kept confidential
within respective affiliated companies. It is not passed on to any third-party,
including Xen Security Project, without your permission.

Email sent to us is read and acknowledged with a non-automated response. For
issues that are complicated and require significant attention, we will open an
investigation and keep you informed of our progress. We might take one or more
of the following steps:

### Publication embargo

If a security issue is reported that is not already publicly disclosed, an
embargo date may be assigned and communicated to the reporter. Embargo
periods will be negotiated by mutual agreement between members of the security
team and other relevant parties to the problem. Members of the security contact
list agree not to publicly disclose any details of the security issue until
the embargo date expires.

### CVE allocation

An security issue is assigned with a CVE number. The CVE numbers will usually
be allocated by one of the vendor security engineers on the security contact
list.

## When to contact the QEMU Security Contact List

You should contact the Security Contact List if:
* You think there may be a security vulnerability in QEMU.
* You are unsure about how a known vulnerability affects QEMU.
* You can contact us in English. We are unable to respond in other languages.

## When *not* to contact the QEMU Security Contact List
* You need assistance in a language other than English.
* You require technical assistance (for example, "how do I configure QEMU?").
* You need help upgrading QEMU due to security alerts.
* Your issue is not security related.

## How impact and severity of a bug is decided

All security issues in QEMU are not equal. Based on the parts of the QEMU
sources wherein the bug is found, its impact and severity could vary.

In particular, QEMU is used in many different scenarios; some of them assume
that the guest is trusted, some of them don't. General considerations to triage
QEMU issues and decide whether a configuration is security sensitive include:

* Is there any feasible way for a malicious party to exploit this flaw and
  cause real damage? (e.g. from a guest or via downloadable images)
* Does the flaw require access to the management interface? Would the
  management interface be accessible in the scenario where the flaw could cause
  real damage?
* Is QEMU used in conjunction with a hypervisor (as opposed to TCG binary
  translation)?
* Is QEMU used to offer virtualised production services, as opposed to usage
  as a development platform?

Whenever some or all of these questions have negative answers, what appears to
be a major security flaw might be considered of low severity because it could
only be exercised in use cases where QEMU and everything interacting with it is
trusted.

For example, consider upstream commit [9201bb9 "sdhci.c: Limit the maximum
block size"](http://git.qemu.org/?p=qemu.git;a=commit;h=9201bb9), an of out of
bounds (OOB) memory access (ie. buffer overflow) issue that was found and fixed
in the SD Host Controller emulation (hw/sd/sdhci.c).

On the surface, this bug appears to be a genuine security flaw, with potentially
severe implications. But digging further down, there are only two ways to use
SD Host Controller emulation, one is via 'sdhci-pci' interface and the other
is via 'generic-sdhci' interface.

Of these two, the 'sdhci-pci' interface had actually been disabled by default
in the upstream QEMU releases (commit [1910913 "sdhci: Make device "sdhci-pci"
unavailable with -device"](http://git.qemu.org/?p=qemu.git;a=commit;h=1910913)
at the time the flaw was reported; therefore, guests could not possibly use
'sdhci-pci' for any purpose.

The 'generic-sdhci' interface, instead, had only one user in 'Xilinx Zynq
Baseboard emulation' (hw/arm/xilinx_zynq.c). Xilinx Zynq is a programmable
systems on chip (SoC) device. While QEMU does emulate this device, in practice
it is used to facilitate cross-platform developmental efforts, i.e. QEMU is
used to write programs for the SoC device. In such developer environments, it
is generally assumed that the guest is trusted.

And thus, this buffer overflow turned out to be a security non-issue.

## What to Send to the QEMU Security Contact List

Please provide as much information about your system and the issue as possible
when contacting the list.
