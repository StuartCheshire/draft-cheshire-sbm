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
  latest: "https://StuartCheshire.github.io/draft-cheshire-sbm/draft-cheshire-sbm.html"

author:
 -
    fullname: Stuart Cheshire
    organization: Apple Inc.
    email: cheshire@apple.com

normative:

informative:

  Bloat1:
    author:
     - ins: J. Gettys
    title: "Whose house is of glasse, must not throw stones at another"
    date: December 2010
    target: https://gettys.wordpress.com/2010/12/06/whose-house-is-of-glasse-must-not-throw-stones-at-another/
  Bloat2:
    author:
     - ins: J. Gettys
     - ins: K. Nichols
    title: "Bufferbloat: Dark Buffers in the Internet"
    date: November 2011
    seriesinfo: ACM Queue, Volume 9, issue 11
    target: https://queue.acm.org/detail.cfm?id=2071893
  Bloat3:
    author:
     - ins: J. Gettys
     - ins: K. Nichols
    title: "Bufferbloat: Dark Buffers in the Internet"
    date: January 2012
    seriesinfo: Communications of the ACM, Volume 55, Number 1
    target: https://dl.acm.org/doi/10.1145/2063176.2063196
  Cake:
    author:
     - ins: T. Høiland-Jørgensen
     - ins: D. Taht
     - ins: J. Morton
    title: "Piece of CAKE: A Comprehensive Queue Management Solution for Home Gateways"
    date: June 2018
    seriesinfo: 2018 IEEE International Symposium on Local and Metropolitan Area Networks (LANMAN)
    target: https://ieeexplore.ieee.org/document/8475045
  Demo:
    author:
     - ins: S. Cheshire
    title: "Your App and Next Generation Networks"
    date: June 2015
    seriesinfo: Apple Worldwide Developer Conference
    target: https://developer.apple.com/videos/play/wwdc2015/719/?time=2199
  RFC3168:
  RFC6143:
  RFC8033:
  RFC8290:
  RFC9330:

--- abstract

In the past decade there has been growing awareness about the
harmful effects of bufferbloat in the network, and there has
been good work on developments like L4S to address that problem.
However, bufferbloat on the sender itself remains a significant
additional problem, which has not received similar attention.
This document offers techniques and guidance for host networking
software to avoid network traffic suffering unnecessary delays
caused by excessive buffering at the sender. These improvements
are broadly applicable across all datagram and transport
protocols (UDP, TCP, QUIC, etc.) on all operating systems.

--- middle

# Conventions and Definitions

{::boilerplate bcp14-tagged}

# Introduction

In 2010 Jim Gettys identified the problem
of how excessive buffering in networks adversely affects
delay-sensitive applications {{Bloat1}}{{Bloat2}}{{Bloat3}}.
This important work identifying a non-obvious problem
has lead to valuable developments to improve this situation,
like fq_codel {{RFC8290}}, PIE {{RFC8033}}, Cake {{Cake}}
and L4S {{RFC9330}}.

However, excessive buffering at the source
-- in the sending devices themselves --
can equally contribute to degraded performance
for delay-sensitive applications,
and this problem has not yet received
a similar level of attention.

This document describes the source buffering problem,
steps that have been taken so far to address the problem,
shortcomings with those existing solutions,
and new mechanisms that work better.

To explain the problem and the solution,
this document begins with some historical background
about why computers have buffers in the first place,
and why buffers are useful.
This document explains the need for backpressure on
senders that are able to exceed the network capacity,
and separates backpressure mechanisms into
direct backpressure and indirect backpressure.

The document concludes by describing
the TCP\_REPLENISH\_TIME socket option,
and its equivalent for other networking APIs.

# Source Buffering

Starting with the most basic principles,
computers have always had to deal with the situation
where software is able to generate output data
faster than the physical medium can accept it.
The software may be sending data to a paper tape punch,
to an RS232 serial port (UART),
or to a printer connected via a parallel port.
The software may be writing data to a floppy disk
or a spinning hard disk.
It was self-evident to computer designers that it would
be unacceptable for data to be lost in these cases.

# Direct Backpressure

The early solutions were simple.
When an application wrote data to a file on a floppy disk,
the file system “write” API would not return to the caller
until the data had actually been written to the floppy disk.
This had the natural effect of slowing down
the application so it could not exceed
the capacity of the medium to accept the data.

Soon it became clear that these simple synchronous APIs
unreasonably limited the performance of the system.
If, instead, the file system “write” API
were to return to the caller immediately
-- even though the actual write to the
spinning hard disk had not yet completed --
then the application could get on with other
useful work while the actual write to the
spinning hard disk proceeded in parallel.

Some systems allowed a single asynchronous write
to the spinning hard disk to proceed while
the application software performed other processing.
Other systems allowed multiple asynchronous writes to be enqueued,
but even these systems generally imposed some upper bound on
the amount of outstanding incomplete writes they would support.
At some point, if the application software persisted in
trying to write data faster than the medium could accept it,
then the application would be throttled in some way,
either by making the API call a blocking call
(simply not returning control to the application,
removing its ability to do anything else)
or by returning a Unix EWOULDBLOCK error or similar
(to inform the application that its API call had
been unsuccessful, and that it would need to take
action to write its data again at a later time).

It is informative to observe a comparison with graphics cards.
Most graphics cards support double-buffering.
This allows one frame to be displayed while
the CPU and GPU are working on generating the next frame.
This concurrency allows for greater efficiency,
by enabling two actions to be happening at the same time.
But quintuple-buffering is not better than double-buffering.
Having a pipeline five frames deep, or ten frames,
or fifty frames, is not better than two frames.
For a fast-paced video game, having a display pipeline fifty
frames deep, where every frame is generated, then waits in
the pipeline, and then is displayed fifty frames later,
would not improve performance or efficiency,
but would cause an unacceptable delay between a player
action and seeing the results of that action on the screen.
It is beneficial for the video game to work on preparing
the next frame while the previous frame is being displayed,
but it is not beneficial for the video game to get multiple
frames ahead of the frame currently being displayed.

Another reason that it is good not to permit an
excessive amount of unsent data to be queued up
is that once data is committed to a buffer,
there are generally limited options for changing it.
Some systems may provide a mechanism to flush the entire
buffer and discard all the data, but mechanisms to
selectively remove or re-order enqueued data
are complicated and rare.
While it could be possible to add such mechanisms,
on balance it is simpler simply to avoid committing
too much unsent data to the buffer in the first place.
If the backlog of unsent data is kept reasonably low,
that gives the source more flexibility decide what to
put into the buffer next, when that opportunity arises.

# Indirect Backpressure

All of the situations described above using “direct backpressure”
are one-hop communication where the receiving device is
connected more-or-less directly to the CPU generating the data.
In these cases it is relatively simple for the receiving device
to exert backpressure to influence the rate at which the CPU sends data.

When we introduce multi-hop networking,
the situation becomes more complicated.
When a flow of packets travels 30 hops though
a network, the bottleneck hop may be quite distant
from the original source of the data stream.

For example, when a cable modem
with a 35Mb/s output rate of receives
an excessive flow of packets coming in
on its Gb/s Ethernet interface,
the cable modem cannot directly cause
the sending application to block or receive an EWOULDBLOCK error.
The cable modem’s choices are limited to
enqueueing an incoming packet,
discarding an incoming packet,
or enqueueing an incoming packet and
marking with an ECN CE mark {{RFC3168}}.

The reasons the cable modem’s choices are so limited
are because of security and packet size constraints.

Security and trust concerns revolve around preventing a
malicious entity from performing a denial-of-service attack
against a victim device by sending fraudulent messages that
would cause it to reduce its transmission rate.
It is particularly important to guard against an off-path attacker
being able to do this. This concern is addressed if queue size
feedback generated in the network follows the same path already
taken by the data packets and their subsequent acknowledgement
packets. The logic is that any on-path device that is able to
modify data packets (changing the ECN bits in the IP header)
could equally well corrupt or discard packets entirely.
Thus, trusting ECN information from these devices does not
increase security concerns, since these devices could already
perform more malicious actions anyway. The sender already
trusts the receiver to generate accurate acknowledgement
packets, so also trusting it to report ECN information back
to the sender does not increase the security risk.

A consequence of this security requirement is that it takes a
full round trip time for the source to learn about queue state
in the network. In many common cases this is not a significant
deficiency. For example, if a user is receiving data from a
well connected server on the Internet, and the network
bottleneck is the last hop on the path (e.g., the Wi-Fi hop to
the user’s smartphone in their home) then the location where
the queue is building up (the Wi-Fi Access Point) is very close
to the receiver, and having the receiver echo the queue state
information back to the sender does not add significant delay.

Packet size constraints, particularly scarce bits available
in the IP header, mean that for pragmatic reasons the ECN
queue size feedback is limited to two states: “The source
may try sending a little faster if desired,” and, “The
source should reduce its sending rate.” Use of these
increase/decrease indications in successive packets allows
the sender to converge on the ideal transmission rate, and
then to oscillate slightly around the ideal transmission
rate as it continues to track changing network conditions.

Discarding or marking an incoming packet are
what we refer to as indirect backpressure,
with the assumption that these actions will eventually
result in the sending application being throttled
via having a write call blocked,
returning an EWOULDBLOCK error,
or exerting some other form of backpressure that
causes the source application
to temporarily pause sending new data.

# Case Study -- TCP\_NOTSENT\_LOWAT

In April 2011 the author was investigating
sluggishness with Mac OS Screen Sharing,
which uses the VNC Remote Framebuffer (RFB) protocol {{RFC6143}}.
Initially it seemed like a classic case of network bufferbloat.
However, deeper investigation revealed that in this case
the network was not responsible for the excessive delay --
the excessive delay was being caused by
excessive buffering on the sending device itself.

In this case the network connection was a relatively slow
DSL line (running at about 500 kb/s) and
the socket send buffer (SO_SNDBUF) was set to 128 kilobytes.
With a 50 ms round-trip time,
about 3 kilobytes (roughly two packets)
was sufficient to fill the bandwidth-delay product of the path.
The remaining 125 kilobytes available in 128 kB socket send buffer
was simply holding bytes that had not even been sent yet.
At 500 kb/s throughput (62.5 kB/s),
this meant that every byte written by the VNC RFB server
spent two seconds sitting in the socket send buffer
before it even left the source machine.
Clearly, delaying every sent byte by two seconds
resulted in a very sluggishness screen sharing experience,
and it did not yield any useful benefit like
higher throughput or lower CPU utilization.

This lead to the creation in May 2011
of a new socket option on Mac OS and iOS
called “TCP\_NOTSENT\_LOWAT”.
This new socket option provided the ability for
application software (like the VNC RFB server)
to specify a low-water mark threshold for the
minimum amount of **unsent** data it would like
to have waiting in the socket send buffer.
Instead of encouraging the application to
fill the socket send buffer to its maximum capacity,
the socket send buffer would hold just the data
that had been sent but not yet acknowledged
(enough to fully occupy the bandwidth-delay product
of the network path and fully utilize the available capacity)
plus some **small** amount of additional unsent data waiting to go out.
Some **small** amount of unsent data waiting to go out is
beneficial, so that the network stack has data
ready to send when the opportunity arises
(e.g., a TCP ACK arrives signalling
that previous data has now been delivered).
Too much unsent data waiting to go out
-- in excess of what the network stack
might soon be able to send --
is harmful for delay-sensitive applications
because it increases delay without
meaningfully increasing throughput or utilization.

Empirically it was found that setting an
unsent data low-water mark threshold of 16 kilobytes
worked well for VNC RFB screen sharing.
When the amount of unsent data fell below this
low-water mark threshold, kevent() would
wake up the VNC RFB screen sharing application
to begin work on preparing the next frame to send.
Once the VNC RFB screen sharing application
had prepared the next frame and written it
to the socket send buffer,
it would again call kevent() to block and wait
to be notified when it became time to begin work
on the following frame.
This allows the VNC RFB screen sharing server
to stay just one frame ahead of
the frame currently being sent over the network,
and not inadvertently get multiple frames ahead.
This provided enough unsent data waiting to go out
to fully utilize the capacity of the path,
without buffering so much unsent data
that it adversely affected usability.

A demo showing the benefits of using TCP\_NOTSENT\_LOWAT
with VNC RFB screen sharing was shown at the
Apple Worldwide Developer Conference in June 2015 {{Demo}}.

# Shortcomings of TCP\_NOTSENT\_LOWAT

While TCP\_NOTSENT\_LOWAT achieved its initial intended goal,
later operational experience has revealed some shortcomings.

## Platform Differences

The Linux network maintainers implemented a TCP
socket option with the same name, but different behavior.
While the Apple version of TCP\_NOTSENT\_LOWAT was
focussed on reducing delay,
the Linux version was focussed on reducing kernel memory usage.
The Apple version of TCP\_NOTSENT\_LOWAT controls
a low-water mark, below which the application is signalled
that it is time to begin working on generating fresh data.
The Linux version determines a high-water mark for unsent data,
above which the application is **prevented** from writing any more,
even if it has data prepared and ready to enqueue.
Setting TCP\_NOTSENT\_LOWAT to 16 kilobytes works well on Apple
systems, but can severely limit throughput on Linux systems.
This has lead to confusion among developers and makes it difficult
to write portable code that works on both platforms.

## Time Versus Bytes

The original thinking on TCP\_NOTSENT\_LOWAT focussed on
the number of unsent bytes remaining, but it soon became
clear that the relevant quantity was time, not bytes.
The quantity of interest to the sending application
was how much advance notice it would get of impending
data exhaustion, so that it would have enough time
to generate its next logical block of data.
On low-rate paths (e.g., 250 kb/s and less)
16 kilobytes of unsent data could still result
in a fairly significant unnecessary queueing delay.
On high-rate paths (e.g., Gb/s and above)
16 kilobytes of unsent data could be consumed
very quickly, leaving the sending application
insufficient time to generate its next logical block of data
before the unsent backlog ran out
and available network capacity was left unused.
It became clear that it would be more useful for the
sending application specify how much advance notice
of data exhaustion it required (in milliseconds, or microseconds),
depending on how much time the application anticipated
needing to generate its next logical block of data.
The application could perform this calculation itself,
calculating the estimated current data rate and dividing
that by its desired advance notice time, to compute the number
of outstanding unsent bytes corresponding to that desired time.
However, the application would have to keep adjusting its
TCP\_NOTSENT\_LOWAT value as the observed data rate changed.
Since the transport protocol already knows the number of
unacknowledged bytes in flight, and the current round-trip delay,
the transport protocol is in a better position
to perform this calculation.
The transport protocol also knows if features like hardware
offload and stretch acks are being used, which could impact
the burstiness of consumption of unsent bytes.
If stretch acks are being used, and a couple of acks arrive
acknowledging 12 kilobytes each, then a 16 kilobyte unsent
backlog could be consumed almost instantly.
Therefore it is better to have the transport protocol
use all the information it has available to estimate
when it expects to run out of unsent data.

## Other Transport Protocols

TCP\_NOTSENT\_LOWAT was initially defined only for TCP.
It would be useful to define equivalent delay management
capabilities for other transport protocols, like QUIC.

# TCP\_REPLENISH\_TIME

Because of these lessons learned, this document proposes
a new mechanism, TCP\_REPLENISH\_TIME.

The new TCP\_REPLENISH\_TIME socket option specifies the
threshold for notifying an application of impending data
exhaustion in terms of microseconds, not bytes.
It is the job of the transport protocol to compute its
best estimate of when the amount of remaining unsent data
falls below the threshold.

The new TCP\_REPLENISH\_TIME socket option
should have the same semantics across all
operating systems and network stack implementations.

Other transport protocols, like QUIC,
and other network APIs not based on BSD Sockets,
should provide equivalent time-based backlog-management
mechanisms, as appropriate to their API design.

The time-based estimate does not need to be perfectly accurate,
either on the part of the transport protocol estimating how much
time remains before the backlog of unsent data is exhausted,
or on the part of the application estimating how much
time it will need generate its next logical block of data.
If the network data rate increases significantly, or a group of
delayed acknowledgments all arrive together, then the transport
protocol could end up discovering that it has overestimated how
much time remains before the data is exhausted.
If the operating system scheduler is slow to schedule the
application process, or the CPU is busy with other tasks,
then the application may take longer than expected
to generate its next logical block of data.
These situations are not considered to be serious problems,
especially if they only occur infrequently.
For a delay-sensitive application, having some reasonable
mechanism to avoid an excessive backlog of unsent data is
dramatically better than having no such mechanism at all.
Occasional overestimates or underestimates do not
negate the benefit of this capability.

# Applicability

This time-based backlog management is applicable anywhere
that a queue of unsent data may build up on the sending device.

Since multi-hop network protocols already implement
indirect backpressure in the form of discarding or marking packets,
it can be tempting to use this mechanism
for the first hop of the path too.
However, this is not an ideal solution because indirect
backpressure from the network is very crude compared to
the much richer direct backpressure
that is available within the sending device itself.
Relying on indirect backpressure by
discarding or marking a packet in the sending device itself
is a crude rate-control signal, because it takes a full network
round-trip time before the effect of that drop or mark is
observed at the receiver and echoed back to the sender, and
it may take multiple such round trips before it finally
results in an appropriate reduction in sending rate.

In contrast to queue buildup in the network, queue buildup
at the sending device has different properties.
When it is the source device itself that is building up a backlog
of unsent data, it has more freedom about to handle this.
When the source of the data and the location of the backlog is
the same device, network security and trust concerns do not apply.
When the mechanism we use to communicate about queue state
is a software API instead of packets sent though a network,
we do not have the constraint of having to work within
limited IP packet header space, and the delivery of queue
state STOP/GO information to the source is immediate.

Direct backpressure can be achieved
simply making an API call block,
returning a Unix EWOULDBLOCK error,
or using equivalent mechanisms in other APIs,
and has the effect of immediately halting the flow of new data.
Similarly, when the system becomes able to accept more data,
unblocking an API call, indicating that a socket
has become writable using select() or kevent(),
or equivalent mechanisms in other APIs,
has the effect of immediately allowing the production of more data.

Where direct backpressure mechanisms are possible they
should be preferred over indirect backpressure mechanisms.

If the outgoing network interface on the source device
is the slowest hop of the network path, then this
is where the backlog of unsent data will accumulate.

In addition to physical bottlenecks,
devices also have intentional algorithmic bottlenecks:

* If the TCP receive window is full, then the sending TCP
implementation will voluntarily refrain from sending new data,
even though the device’s outgoing first-hop interface is easily
capable of sending those packets.

* The transport protocol’s rate management (congestion control) algorithm
may determine that it should delay before sending more data, so as
not to overflow a queue at some other bottleneck within the network.

* When packet pacing is being used, the sending network
implementation may choose voluntarily to moderate the rate at
which it emits packets, so as to smooth the flow of packets into
the network, even though the device’s outgoing first-hop interface
might be easily capable of sending at a much higher rate.

Whether the source application is constrained
by a physical bottleneck on the sending device, or
by an algorithmic bottleneck on the sending device,
the benefits of not overcommitting data to the outgoing buffer are similar.

The goal is for the application software to be able to
write chunks of data large enough to be efficient,
without writing too many of them too quickly.
This avoids the unfortunate situation where a delay-sensitive
application inadvertently writes many blocks of data
long before they will actually depart the source machine,
such that by the time the enqueued data is actually sent,
the application may have newer data that it would rather send instead.
By deferring generating data until the networking code is
actually ready to send it, the application retains more precise
control over what data will be sent when the opportunity arises.

# Security Considerations

No security concerns are anticipated resulting from reducing
the amount of stale data sitting in buffers at the sender.

# IANA Considerations

This document has no IANA actions.

--- back

# Acknowledgments
{:numbered="false"}

TODO Acknowledgments.
