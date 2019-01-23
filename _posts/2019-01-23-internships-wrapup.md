---
layout: post
title:  "GSoC and Outreachy 2018 retrospective"
date:   2019-01-23 07:50:00 +0100
categories: [gsoc, outreachy, internships]
---
QEMU participates in open source internship programs including Google Summer of
Code (GSoC) and Outreachy.  These full-time remote work opportunities allow
talented new developers to get involved in our community.  This post highlights
what our interns achieved in 2018.

## micro:bit board emulation

Julia Suvorova (Outreachy) and Steffen Görtz (GSoC) tackled adding emulation
support for the [micro:bit ARM board](https://microbit.org/).  Although QEMU
already has plenty of ARM emulation code, the Cortex-M0 CPU used in the
micro:bit was not yet implemented and the nRF51 system-on-chip was also
missing.

The goal of this project was to run micro:bit programs (usually created with
the [MicroPython](https://python.microbit.org/v/1.1) or
[Javascript/Blocks](https://makecode.microbit.org/) IDEs) with a core set of
emulated devices, including the serial port, pushbuttons, and LEDs.

QEMU 3.1 already shipped the groundwork for the new `qemu-system-arm -M
microbit` machine type.  Enough functionality to run basic micro:bit programs
is expected in the next QEMU release.

This project was mentored by Jim Mussared, Joel Stanley, and Stefan Hajnoczi.

## Patchew REST API improvements

Shubham Jain (GSoC) created a REST API for the Patchew continuous integration
system that is at the heart of QEMU's development process.  The previous API
was not RESTful and exposed database schema internals.

The improvements to the REST API have been included into Patchew and are
deployed on <a href="https://patchew.org/">patchew.org</a>.  They are not in
use yet, pending more work on authentication; this may be the topic of a future
Summer of Code internship.

This project was mentored by Paolo Bonzini and Fam Zheng.

## Qtest Driver Framework

Emanuele Esposito (GSoC) enhanced QEMU's test infrastructure with an engine
that starts tests with all variants of devices that they are capable of
driving.

This is a complicated task in QEMU since certain devices and buses are
available in an architecture-specific way on each emulation target, making it
hard to write test cases without lots of hardcoded dependencies - and to keep
them up-to-date!

The qgraph framework that Emanuele created eliminates the need to hardcode each
variant into the test.  Emanuele also converted several existing tests.  His
framework was also <a
href="https://www.youtube.com/watch?v=N8Go4NEw0Ss">presented at KVM Forum 2018
by Laurent Vivier</a> and should be merged in 4.0.

This project was mentored by Paolo Bonzini and Laurent Vivier.

## Vulkan-izing VirGL

Nathan Gauër (GSoC) improved VirGL, which provides an OpenGL path well
supported on Linux guests. On the host, QEMU offers several console back-ends,
from EGL to SDL. Adding a Vulkan path will require to change the current VirGL
API, write new guest drivers, and also offer a way to display the output. This
is a huge task, which can be split in several sub-projects. Expending the
current VirGL API to support Vulkan is the first step.

Code is available [here](https://github.com/Keenuts/vulkan-virgl).

This project was mentored by Marc-André Lureau.

## Stay tuned for 2019 internships!

QEMU will apply to Google Summer of Code and Outreachy again in 2019.  We hope
to offer more great open source internship opportunities for new developers.
