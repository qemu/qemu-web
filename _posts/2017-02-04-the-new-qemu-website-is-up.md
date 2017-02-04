---
layout: post
title:  "A new website for QEMU"
date:   2017-02-04 09:40:11 +0200
author: Paolo Bonzini
categories: [contributing, 'web site']
---
At last, QEMU's new website is up!

The new site aims to be simple and provides the basic information
needed to download and start contributing to QEMU.  It complements the
[wiki](http://wiki.qemu-project.org/), which remains the central point for
developers to share information quickly with the rest of the community.

We tried to test the website on most browsers and to make it lightweight
and responsive.  It is built using [Jekyll](https://jekyllrb.com/)
and the source code for the website can be cloned from the
[qemu-web.git](http://git.qemu-project.org/?p=qemu-web.git;a=summary)
repository.  Just like for any other project hosted by QEMU, the best way
to propose or contribute a new change is by sending a patch through the
[qemu-devel@nongnu.org](https://lists.nongnu.org/mailman/listinfo/qemu-devel)
mailing list.

For example, if you would like to add a new screenshot to the homepage,
you can clone the `qemu-web.git` repository, add a PNG file to the
[`screenshots/`](http://git.qemu-project.org/?p=qemu-web.git;a=tree;f=screenshots;hb=HEAD)
directory, and edit the [`_data/screenshots.yml`](http://git.qemu-project.org/?p=qemu-web.git;a=blob;f=_data/screenshots.yml;hb=HEAD)
file to include the new screenshot.

Blog posts about QEMU are also welcome; they are simple HTML or Markdown
files and are stored in the [`_posts/`](http://git.qemu-project.org/?p=qemu-web.git;a=tree;f=_posts;hb=HEAD)
directory of the repository.
