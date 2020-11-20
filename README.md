RPKI Console
============

The RPKI console exists to provide operators with insight into the RPKI
ecosystem and help identify how the distributed database works.

The software has only been tested on OpenBSD.

Demo instance
=============

A live instance is available at http://console.rpki-client.org/

TALs
====
You have to obtain the TALs yourself, those are not included in this project.

PEM print utilities
===================

The `test-mft`, `test-cert`, `test-roa`, and `test-tal` utilities are part of the
OpenBSD regression framework. To obtain a copy please downlaod the OpenBSD source
code tree, update to the latest version using `cvs`.

easy way:

```
cvs -d anoncvs@anoncvs.ca.openbsd.org:/cvs checkout -P src/regress/usr.sbin/rpki-client
```

hard way:

```
cd /usr/src
ftp https://cdn.openbsd.org/pub/OpenBSD/6.8/src.tar.gz
tar fxz src.tar.gz && rm src.tar.gz
cvs -d anoncvs@anoncvs.ca.openbsd.org:/cvs up -Pd
cd regress/usr.sbin/rpki-client/
make
doas cp -v test-{cert,mft,tal,roa} /usr/local/bin
```
