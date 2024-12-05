---
title: "Source Buffer Management"
abbrev: "Source Buffer Management"
category: info

docname: draft-cheshire-sbm
submissiontype: independent
number:
date:
v: 3
# area: WIT
# workgroup: TSVWG Transport and Services Working Group
keyword:
 - Bufferbloat
 - Latency
 - Responsiveness
venue:
#  group: WG
#  type: Working Group
#  mail: WG@example.com
#  arch: https://example.com/WG
  github: "StuartCheshire/draft-cheshire-sbm"
  latest: "&lt;https://StuartCheshire.github.io/draft-cheshire-sbm/draft-cheshire-sbm.html&gt;"

author:
 -
    fullname: Stuart Cheshire
    organization: Apple Inc.
    email: cheshire@apple.com

normative:

informative:

--- abstract

In the past decade there has been growing awareness about the
harmful effects of bufferbloat in the network, and there has been
good work on developments like L4S to address that problem.
However, bufferbloat on the sender itself remains a significant
additional problem, which has not received similar attention.
This document offers techniques and guidance
for host networking software to avoid unnecessary delays
for network traffic caused by excessive buffering at the sender,
which are broadly applicable across
all datagram and transport protocols (UDP, TCP, QUIC, etc.)
on all operating systems.

--- middle

# Conventions and Definitions

{::boilerplate bcp14-tagged}

# Security Considerations

No security concerns are anticipated resulting from reducing
the amount of stale data sitting in buffers at the sender.

# IANA Considerations

This document has no IANA actions.

--- back

# Acknowledgments
{:numbered="false"}

TODO Acknowledgments.
