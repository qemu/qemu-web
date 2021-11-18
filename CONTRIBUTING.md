# Contributing to qemu-web

The QEMU project accepts code contributions to the website as patches sent to
the the developer mailing list:

https://lists.nongnu.org/mailman/listinfo/qemu-devel

You should also CC the website maintainers:

* Thomas Huth <thuth@redhat.com>
* Paolo Bonzini <pbonzini@redhat.com>

For further guidance on sending patches consult:

https://qemu.org/contribute/submit-a-patch/

It is expected that contributors check the rendered website before submitting
patches. This is possible by either running jekyll locally, or by using the
GitLab CI and Pages infrastructure.

Any branch that is pushed to a GitLab fork will result in a CI job being run
visible at

https://gitlab.com/yourusername/qemu-web/-/pipelines

The rendered result can be then viewed at

https://yourusername.gitlab.io/qemu-web

Contributions submitted to the project must be in compliance with the
Developer Certificate of Origin Version 1.1. This is documented at:

https://developercertificate.org/

To indicate compliance, each commit in a series must have a "Signed-off-by"
tag with the submitter's name and email address. This can be added by passing
the ``-s`` flag to ``git commit`` when creating the patches.
