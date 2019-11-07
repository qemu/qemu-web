---
layout: post
title:  "Fuzzing QEMU Device Emulation"
date:   2019-11-07 07:50:00 +0200
author: Stefan Hajnoczi and Alexander Oleinik
categories: [fuzzing, gsoc, internships]
---
QEMU (https://www.qemu.org/) emulates a large number of network cards, disk
controllers, and other devices needed to simulate a virtual computer system,
called the "guest".

The guest is untrusted and QEMU may even be used to run malicious
software, so it is important that bugs in emulated devices do not
allow the guest to compromise QEMU and escape the confines of the
guest. For this reason a Google Summer of Code project was undertaken
to develop fuzz tests for emulated devices.

![QEMU device emulation attack surface](/screenshots/fuzzing-intro.png)

Fuzzing is a testing technique that feeds random inputs to a program
in order to trigger bugs. Random inputs can be generated quickly
without relying on human guidance and this makes fuzzing an automated
testing approach.

## Device Fuzzing
Emulated devices are exposed to the guest through a set of registers
and also through data structures located in guest RAM that are
accessed by the device in a process known as Direct Memory Access
(DMA). Fuzzing emulated devices involves mapping random inputs to the
device registers and DMA memory structures in order to explore code
paths in QEMU's device emulation code.

![Device fuzzing overview](/screenshots/fuzzing.png)

Fuzz testing discovered an assertion failure in the virtio-net network
card emulation code in QEMU that can be triggered by a guest. Fixing
such bugs is usually easy once fuzz testing has generated a reproducer.

Modern fuzz testing intelligently selects random inputs such that new
code paths are explored and previously-tested code paths are not
tested repeatedly. This is called coverage-guided fuzzing and
involves an instrumented program executable so the fuzzer can detect
the code paths that are taken for a given input. This was
surprisingly effective at automatically exploring the input space of
emulated devices in QEMU without requiring the fuzz test author to
provide detailed knowledge of device internals.

## How Fuzzing was Integrated into QEMU
Device fuzzing in QEMU is driven by the open source libfuzzer library
(https://llvm.org/docs/LibFuzzer.html). A special build of QEMU
includes device emulation fuzz tests and launches without running a
normal guest. Instead the fuzz test directly programs device
registers and stores random data into DMA memory structures.

The next step for the QEMU project will be to integrate fuzzing into
Google's OSS-Fuzz (https://google.github.io/oss-fuzz/) continuous
fuzzing service. This will ensure that fuzz tests are automatically
run after new code is merged into QEMU and bugs are reported to the
community.

## Conclusion
Fuzzing emulated devices has already revealed bugs in QEMU that would
have been time-consuming to find through manual testing approaches.
So far only a limited number of devices have been fuzz-tested and we
hope to increase this number now that the foundations have been laid.
The goal is to integrate these fuzz tests into OSS-Fuzz so that fuzz
testing happens continuously.

This project would not have been possible without Google's generous
funding of Google Summer of Code. Alexander Oleinik developed the
fuzzing code and was mentored by Bandan Das, Paolo Bonzini, and Stefan
Hajnoczi.
