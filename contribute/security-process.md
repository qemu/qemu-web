---
title: Security Process
permalink: /contribute/security-process/
---

Please report any suspected security issue in QEMU to the security mailing
list at:

* [\<qemu-security@nongnu.org\>](https://lists.nongnu.org/mailman/listinfo/qemu-security)

To report an issue via [GPG](https://gnupg.org/) encrypted email, please send
it to the Red Hat Product Security team at:

* [\<secalert@redhat.com\>](https://access.redhat.com/security/team/contact/#contact)

**Note:** after the triage, encrypted issue details shall be sent to the upstream
'qemu-security' mailing list for archival purposes.

## How to report an issue:

* Please include as many details as possible in the issue report.
  Ex:
    - QEMU version, upstream commit/tag
    - Host & Guest architecture x86/Arm/PPC, 32/64 bit etc.
    - Affected code area/snippets
    - Stack traces, crash details
    - Malicious inputs/reproducer steps etc.
    - Any configurations/settings required to trigger the issue.

* Please share the QEMU command line used to invoke a guest VM.

* Please specify whom to acknowledge for reporting this issue.

## How we respond:

* Process of handling security issues comprises following steps:

  0) **Acknowledge:**
    - A non-automated response email is sent to the reporter(s) to acknowledge
      the reception of the report. (*60 day's counter starts here*)

  1) **Triage:**
    - Examine the issue details and confirm whether the issue is genuine
    - Validate if it can be misused for malicious purposes
    - Determine its worst case impact and severity
      [Low/Moderate/Important/Critical]

  2) **Response:**
    - Negotiate embargo timeline (if required, depending on severity)
    - Request a [CVE](https://cveform.mitre.org/) and open an upstream
      [bug](https://www.qemu.org/contribute/report-a-bug/)
    - Create an upstream fix patch annotated with
        - CVE-ID
        - Link to an upstream bugzilla
        - Reported-by, Tested-by etc. tags
    - Once the patch is merged, close the upstream bug with a link to the
      commit
        - Fixed in: <commit hash/link>

* Above security lists are operated by select analysts, maintainers and/or
  representatives from downstream communities.

* List members follow a **responsible disclosure** policy. Any non-public
  information you share about security issues, is kept confidential within
  members of the QEMU security team and a minimal supporting staff in their
  affiliated companies. Such information will not be disclosed to third party
  organisations/individuals without prior permission from the reporter(s).

* We aim to process security issues within maximum of **60 days**. That is not
  to say that issues will remain private for 60 days, nope. After the triaging
  step above
    - If severity of the issue is sufficiently low, an upstream public bug
      will be created immediately.
    - If severity of the issue requires co-ordinated disclosure at a future
      date, then the embargo process below is followed, and upstream bug will
      be opened at the end of the embargo period.

  This will allow upstream contributors to create, test and track fix patch(es).

### Publication embargo

* If a security issue is reported that is not already public and its severity
  requires coordinated disclosure, then an embargo date will be set and
  communicated to the reporter(s).

* Embargo periods will be negotiated by mutual agreement between reporter(s),
  members of the security list and other relevant parties to the problem.
  The preferred embargo period is upto [2
  weeks](https://oss-security.openwall.org/wiki/mailing-lists/distros).
  However, longer embargoes may be negotiated if the severity of the issue
  requires it.

* Members of the security list agree not to publicly disclose any details of
  an embargoed security issue until its embargo date expires.

### CVE allocation

Each security issue is assigned a [CVE](https://cveform.mitre.org/) number.
The CVE number is allocated by one of the vendor security engineers on the
security list.

## When to contact the QEMU Security List

You should contact the Security List if:
* You think there may be a security vulnerability in QEMU.
* You are unsure about how a known vulnerability affects QEMU.
* You can contact us in English. We are unable to respond in other languages.

## When *not* to contact the QEMU Security List
* You need assistance in a language other than English.
* You require technical assistance (for example, "how do I configure QEMU?").
* You need help upgrading QEMU due to security alerts.
* Your issue is not security related.

## How impact and severity of a bug is decided

**Security criterion:**
    -> [https://www.qemu.org/docs/master/system/security.html](https://www.qemu.org/docs/master/system/security.html)

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
