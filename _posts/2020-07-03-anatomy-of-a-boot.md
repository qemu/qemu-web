---
layout: post
title:  "Anatomy of a Boot, a QEMU perspective"
date:   2020-07-3 18:00:00:00 +0000
author: Alex Bennée
categories: [boot, softmmu, system, firmware]
---

Have you ever wondered about the process a machine goes through to get
to the point of a usable system? This post will give an overview of
how machines boot and how this matters to QEMU. We will discuss
firmware and BIOSes and the things they do before the OS kernel is
loaded and your usable system is finally ready.

## Firmware

When a CPU is powered up it knows nothing about its environment. The
internal state, including the program counter (PC), will be reset to a
defined set of values and it will attempt to fetch the first
instruction and execute it. It is the job of the firmware to bring a
CPU up from the initial few instructions to running in a relatively
sane execution environment. Firmware tends to be specific to the
hardware in question and is stored on non-volatile memory (memory that
survives a power off), usually a ROM or flash device on the computers
main board.

Some examples of what firmware does include:

### Early Hardware Setup

Modern hardware often requires configuring before it is usable. For
example most modern systems won't have working RAM until the memory
controller has been programmed with the correct timings for whatever
memory is installed on the system. Processors may boot with a very
restricted view of the memory map until RAM and other key peripherals
have been configured to appear in its address space. Some hardware
may not even appear until some sort of blob has been loaded into it so
it can start responding to the CPU.

Fortunately for QEMU we don't have to worry too much about this very
low level configuration. The device model we present to the CPU at
start-up will generally respond to IO access from the processor straight
away.

### BIOS or Firmware Services

In the early days of the PC era the BIOS or Basic Input/Output System
provided an abstraction interface to the operating system which
allowed the OS to do basic IO operations without having to directly
drive the hardware. Since then the scope of these firmware services
has grown as systems become more and more complex.

Modern firmware often follows the Unified Extensible Firmware
Interface (UEFI) which provides services like secure boot, persistent
variables and external time-keeping.

There can often be multiple levels of firmware service functions. For
example systems which support secure execution enclaves generally have
a firmware component that executes in this secure mode which the
operating system can call in a defined secure manner to undertake
security sensitive tasks on its behalf.

### Hardware Enumeration

It is easy to assume that modern hardware is built to be discoverable
and all the operating system needs to do is enumerate the various
buses on the system to find out what hardware exists. While buses like
PCI and USB do support discovery there is usually much more on a
modern system than just these two things.

This process of discovery can take some time as devices usually need
to be probed and some time allowed for the buses to settle and the
probe to complete. For purely virtual machines operating in on-demand
cloud environments you may operate with stripped down kernels that
only support a fixed expected environment so they can boot as fast as
possible.

In the embedded world it used to be acceptable to have a similar
custom compiled kernel which knew where everything is meant to be.
However this was a brittle approach and not very flexible. For example
a general purpose distribution would have to ship a special kernel for
each variant of hardware you wanted to run on. If you try and use a
kernel compiled for one platform that nominally uses the same
processor as another platform the result will generally not work.

The more modern approach is to have a "generic" kernel that has a
number of different drivers compiled in which are then enabled based
on a hardware description provided by the firmware. This allows
flexibility on both sides. The software distribution is less concerned
about managing lots of different kernels for different pieces of
hardware. The hardware manufacturer is also able to make small changes
to the board over time to fix bugs or change minor components.

The two main methods for this are the Advanced Configuration and Power
Interface (ACPI) and Device Trees. ACPI originated from the PC world
although it is becoming increasingly common for "enterprise" hardware
like servers. Device Trees of various forms have existed for a while
with perhaps the most common being Flattened Device Trees (FDT).

## Boot Code

The line between firmware and boot code is a very blurry one. However
from a functionality point of view we have moved from ensuring the
hardware is usable as a computing device to finding and loading a
kernel which is then going to take over control of the system. Modern
firmware often has the ability to boot a kernel directly and in some
systems you might chain through several boot loaders before the final
kernel takes control.

The boot loader needs to do 3 things:

  - find a kernel and load it into RAM
  - ensure the CPU is in the correct mode for the kernel to boot
  - pass any information the kernel may need to boot and can't find itself

Once it has done these things it can jump to the kernel and let it get
on with things.

## Kernel

The Kernel now takes over and will be in charge of the system from now
on. It will enumerate all the devices on the system (again) and load
drivers that can control them. It will then locate some sort of
file-system and eventually start running programs that actually do
work.

## Questions to ask yourself

Having given this overview of booting here are some questions you
should ask when diagnosing boot problems.

### Hardware

 - is the platform fixed or dynamic?
 - is the platform enumeratable (e.g. PCI/USB)?

### Firmware

 - is the firmware built for the platform you are booting?
 - does the firmware need storage for variables (boot index etc)?
 - does the firmware provide a service to kernels (e.g. ACPI/EFI)?

### Kernel

 - is the kernel platform specific or generic?
 - how will the kernel enumerate the platform?
 - can the kernel interface talk to the firmware?

## Final Thoughts

When users visit the IRC channel to ask why a particular kernel won't
boot our first response is almost always to check the kernel is
actually matched to the hardware being instantiated. For ARM boards in
particular just being built for the same processor is generally not
enough and hopefully having made it through this post you see why.
This complexity is also the reason why we generally suggest using a
tool like [virt-manager](https://virt-manager.org/) to configure QEMU
as it is designed to ensure the right components and firmware is
selected to boot a given system.
