---
title: Security Process
permalink: /contribute/security-process/
---

## How to disclosure potential issues

**The QEMU project no longer accepts security issue disclosures via email.**

New disclosures must follow the [report a bug](../report-a-bug)
process to file a GitLab issue (work item) for each potential issue,
***marking it as "*confidential*" prior to submission.***

Some important notes when disclosing potential security issues:

* The QEMU project cannot provide an SLA for response to security
  disclosures, or any bug reports in general. Issues will be
  responded to at the discretion of maintainers, subject to their
  available time.

* Attachments added to GitLab *confidential* issues are not themselves
  confidential. If someone knows the randomly generated URL for the
  attachment, they can view the content. Thus be careful where attachment
  URLs are shared, while the issue remains confidential.

* All disclosures will eventually be made public. Thus the content
  or attachments for any issue must not contain data that the reporter
  considers to be sensitive / private.

* Not all areas of QEMU are considered to provide a security
  boundary. Consult the [security guide](https://www.qemu.org/docs/master/system/security.html)
  for details on how QEMU classifies features.

* If an issue affects a feature within the QEMU security boundary,
  but the reporter is unsure of the security implications, err on
  the side of caution and mark it as "*confidential*" initially.

* All important information must be disclosed in the issue description,
  minimizing use of attachments to what is strictly needed. There is
  a strong preference for individual files to be attached directly.
  Avoid the use of archives (zip, tar, 7z, etc) to bundle files where
  practical.

## Handling of disclosures

Disclosures made via "*confidential*" GitLab issues are visible to, and
may be handled by, any QEMU subsystem maintainer with a GitLab account
[associated with the Reporter role in the project](https://gitlab.com/qemu-project/qemu/-/project_members).
Triage may also be performed by one or more automated tools and/or
AI agents run by the project that have been granted access to the
issue tracker.

The first task for maintainers upon receiving a disclosure is to evaluate
eligibility to follow the security triage process.

* Disclosures affecting code / features evaluated to fall under the
[non-virtualization use case](
https://www.qemu.org/docs/master/system/security.html#non-virtualization-use-case),
will generally not be eligible for handling as a security flaw.
Such disclosures should be immediately switched to the public
bug report process by removing the "*confidential*" marker.

* Disclosures affecting code / features evaluated to fall under the
[virtualization use case](
https://www.qemu.org/docs/master/system/security.html#virtualization-use-case),
will be handled under a lightweight security triage process which
emphasizes getting a fix merged to the latest development branch
as quickly as possible.

In all cases reporters are encouraged to develop and propose patches
for issues themselves at time of disclosure, to speed resolution.

**NOTE:** The QEMU project policy is that all security disclosures received
using GitLab "*confidential*" issues **will eventually be made public**. Any
information that the reporter considers to be be sensitive / private **must**
be scrubbed before disclosure.

## Triage process

 * A maintainer will evaluate the circumstances of the issue
   to determine if it can be misused for malicious purposes.

 * If there is no potential for meaningful exploit, the disclosure
   should be switched to the public bug report process by removing
   the "*confidential*" marker and adding the **"Kind::Bug"** and
   **"Workflow::Triaged"** labels.

 * If confirmed as a security flaw, a maintainer will add the
   **"Kind::Security"**, **"Workflow::Confirmed"** and
   **"CVE::Required"** labels.. The latter indicates the need
   for a CNA to allocate a CVE.

 * The maintainer(s) will develop and/or review patch(es)
   for the issue privately, optionally attaching work in
   progress fixes to the GitLab issues. The
   **"Workflow::In Progress"** label can be assigned when
   a maintainer starts working on a fix.

 * When a CVE is allocated, it must be recorded as a comment on
   the GitLab issue, and the **"CVE::Required"** label replaced by
   the **"CVE::Assigned"** label.

 * The maintainer(s) will update the commit message(s) before
   sending a pull request to include the assigned CVE and issue
   URL in the following format:

     ```
     Fixes: CVE-1980-12345
     Resolves: https://gitlab.com/qemu-project/qemu/-/work_items/42
     Reviewed-by: Not Me <notme@elsewhere.com>
     Signed-off-by: Some One <someone@somewhere.com>
     ```

   If multiple commits are required to fix an issue the CVE & issue
   URL must be included in the final commit in the series, and may
   optionally be included in all prior commits.

 * When the maintainer(s) are satisfied that the patch(es) are
   suitable to propose for merge, they must be submitted to
   the qemu-devel mailing list, and follow the normal process
   for merge henceforth. The **"Workflow::Patch Available"**
   label should be assigned at this stage.

 * At the time the proposed patches are sent to qemu-devel, the
   maintainers should remove the "*confidential*" marker from the
   GitLab issue.

 * When the patch is merged into the current development
   branch the issue must be closed. This should usually happen
   automatically if the git commits referenced the GitLab issue
   URL in [the normal format](https://docs.gitlab.com/user/project/issues/managing_issues/#default-closing-pattern).
   The **"Closed::Fixed"** label can be assigned.

The QEMU project currently co-ordinates with Red Hat Product
Security for CVE assignment, in its role as the [CNA of last
resort for OSS projects](https://www.cve.org/PartnerInformation/ListofPartners/partner/redhat).

## Embargo policy

The QEMU project policy is to limit the time that a disclosure has the
"*confidential*" marker applied strictly to the minimum required to develop
and publish a suitable patch and allocate a CVE.

Given the widespread use of AI/LLM based agents for security auditing,
as well as ongoing use of traditional fuzzing and static analysis
tools, the QEMU maintainers consider that any disclosure originating
from automated tools is highly likely to be independently re-discovered,
potentially many times over in a very short timeframe.

Thus the QEMU maintainers will generally reject requests for arbitrary
embargoes unless high severity, extenuating circumstances can be
demonstrated.

If a patch for a confirmed security issue cannot be developed by a
maintainer in a reasonable time, the maintainers may choose to make
a disclosure public without having a patch available. This approach
should only be taken for issues judged to have low severity.
