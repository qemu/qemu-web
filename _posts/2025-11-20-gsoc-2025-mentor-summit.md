---
layout: post
title: "QEMU at Google Summer of Code Mentor Summit 2025"
date: 2025-11-20 09:00:00 +0100
author: Stefano Garzarella
categories: [internships, gsoc, conferences]
---

The Google Summer of Code (GSoC) Mentor Summit 2025 took place from October 23rd
to 25th in Munich, Germany. This event marks the conclusion of the annual
program, bringing together mentors from all over the world. QEMU had another
successful year with several interesting projects (details on our
[organization page](https://summerofcode.withgoogle.com/programs/2025/organizations/qemu)),
and it was a pleasure for me to represent the QEMU community at the summit,
joining mentors from over 100 open source organizations to discuss the program,
share experiences, and talk about open source challenges.

## The Unconference

The summit follows an "unconference" format. There is no pre-planned schedule;
instead, attendees propose sessions on the first day based on what they want to
discuss. Since the event moved to Munich this year, it was a great opportunity
for me to join and meet people from other communities face-to-face.

![gsoc mentor summit schedule](/screenshots/2025-gsoc-mentor-summit.jpg)

## Lightning Talks

During the "Lightning talks" session, mentors had a short slot to introduce
their projects. I presented the project I mentored this summer:
**vhost-user devices in Rust on macOS and \*BSD**.

The student, **Wenyu Huang**, worked on extending `rust-vmm` crates
(specifically `vhost`, `vhost-user-backend`, and `vmm-sys-utils`) to support
vhost-user devices on non-Linux POSIX systems. This work is important for
portability, allowing `rust-vmm` components to run also on macOS and BSD.

You can find the full details and the code in the
[final project report](https://github.com/uran0sH/GSoC2025-vhost-user-bsd-macos/blob/main/README.md).

This project focused primarily on the `rust-vmm` ecosystem rather than QEMU
itself. This was possible thanks to QEMU acting as an umbrella organization,
allowing related projects like `rust-vmm` to participate in the program.

## Sessions and Networking

Networking with other mentors was a key part of the event. It was nice to see
that QEMU is well-recognized; many mentors I met were familiar with the project,
which made it easy to start conversations. We exchanged views on how to handle
the mentorship lifecycle, from interviewing GSoC applicants (and the impact of
AI on that process) to the coding phase. We shared tips on how to best help
students during the summer, such as setting up regular meetings and maintaining
effective communication.

I also attended several sessions covering different topics. The most interesting
discussions were:

* **Operating System Summit:** A gathering of maintainers from various kernels
  (Linux, BSD, etc.) to connect and share updates.
* **Heterogeneous architectures:** A discussion on how AI systems and workloads
  are driving the requirement for heterogeneous architectures (GPUs, FPGAs, and
  other accelerators).
* **Funding your open source project:** A session on sustainability, focusing
  on how other open source projects manage funding and resources.
* **GSoC feedback session:** A meeting with the Google program admins to share
  experiences and suggest improvements for next year.

The "sticker table" and "chocolate table" are traditions of the summit.
I enjoyed trying chocolates from different countries. Unfortunately, I didn't
have any QEMU stickers to share this time. We should definitely plan to bring
a stack for next year!

## Looking Ahead

We really believe that GSoC is a great and useful program, as it brings new
ideas and contributors to our community. We will definitely apply again for
GSoC 2026, and we hope to have the chance to join the Mentor Summit again next
year!
