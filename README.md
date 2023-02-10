RPKI Console
============

The RPKI console exists to provide operators with insight into the RPKI
ecosystem and help identify how the distributed database works.

The software has only been tested on OpenBSD.

Demo instance
=============

A live instance is available at https://console.rpki-client.org/

Why Perl?
=========

This project merely is an exercise in a language I don't often use.

Installation
============

The console uses `jq` to produce the compressed dump, and depends on
`p5-JSON` to produce the per-object JSON blobs.

`# pkg_add jq p5-JSON`
