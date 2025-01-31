all:
	cd /usr/src/usr.sbin/httpd && make obj && make -j4 && doas make install
	cd /var/www && mkdir -p {bin,etc/rpki,usr/lib,usr/libexec,usr/libdata/perl5}
	install /etc/rpki/{afrinic,apnic,arin,lacnic,ripe}.{tal,constraints} /var/www/etc/rpki/
	install rpki.pl /var/www/cgi-bin/
	install /usr/sbin/rpki-client /usr/bin/perl /bin/sh /var/www/bin/
	install /usr/lib/libexpat.so.* /usr/lib/libtls.so.* /usr/lib/libssl.so.* /usr/lib/libcrypto.so.* /usr/lib/libutil.so.* /usr/lib/libz.so.* /usr/lib/libc.so.* /var/www/usr/lib/
	install /usr/lib/libperl.so.* /usr/lib/libm.so.* /var/www/usr/lib/
	install /usr/libexec/ld.so /var/www/usr/libexec/
	cp -rv /usr/libdata/perl5/File /var/www/usr/libdata/perl5
	install /usr/libdata/perl5/{strict,warnings}.pm /var/www/usr/libdata/perl5
	install /usr/libdata/perl5/Carp.pm /var/www/usr/libdata/perl5
	install /usr/libdata/perl5/XSLoader.pm /var/www/usr/libdata/perl5
	install /usr/libdata/perl5/vars.pm /var/www/usr/libdata/perl5
	cp -rv /usr/libdata/perl5/warnings /var/www/usr/libdata/perl5
	install /usr/libdata/perl5/amd64-openbsd/Config.pm /var/www/usr/libdata/perl5
	install /usr/libdata/perl5/Exporter.pm /var/www/usr/libdata/perl5
