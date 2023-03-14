#!/usr/bin/perl
# Copyright (c) 2022 Job Snijders <job@sobornost.net>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;
use File::Basename;
use OpenBSD::Pledge;
use OpenBSD::Unveil;
use Sys::Hostname;

pledge(qw(cpath rpath wpath unveil)) || die "Unable to pledge: $!";

chdir("/var/www/htdocs/console.rpki-client.org") || die "Unable to chdir: $!";

unveil(".", "rwc") || die "Unable to unveil: $!";
unveil() || die "Unable to unveil again: $!";

my $fn;
my $name;
my $path;
my $type;

while (<>) {
	chomp;

	if (/^File: +(.*)$/) {
		($name, $path, $type) = fileparse($1, qr/\.[^.]*/);
		open(FH, '>', $1 . ".html") or die $!;
		print FH "<img border=0 src='/console.gif' /><br />\n<h3>";
		if ($type eq ".mft") { print FH "Manifest"; }
		elsif ($type eq ".roa") { print FH "Route Origin Authorization"; }
		elsif ($type eq ".crl") { print FH "Certificate Revocation List"; }
		elsif ($type eq ".gbr") { print FH "Ghostbusters Record"; }
		elsif ($type eq ".asa") { print FH "Autonomous System Provider Authorization"; }
		elsif ($type eq ".cer") { print FH "Certificate"; }
		elsif ($type eq ".tak") { print FH "Trust Anchor Key"; }
		print FH "\n</h3>\n<pre>" . "\n";
		print FH '$ <strong>rpki-client -vvf ' . $path . $name . $type . "</strong>\n";
		$_ =~ s|($1)$|$name$type (<a href="$name$type">raw</a>, <a href="$name$type.json">json</a>)|;
	}

	if ($type eq ".roa" and /^asID: +(.*)$/) {
		$_ =~ s|($1)$|<a href="/AS$1.html">$1</a>|;
	}

	if ($type eq ".asa" and /^Customer AS: +(.*)$/) {
		$_ =~ s|($1)$|<a href="/AS$1.html">$1</a>|;
	}

	if (/rsync:\/\/(.*)$/ and /[a-z]$/) {
		$_ =~ s|rsync://(.*)$|rsync://<a href="/$1.html">$1</a>|;
	} elsif (/rsync:\/\/(.*)$/) {
		$_ =~ s|rsync://(.*)$|rsync://<a href="/$1">$1</a>|;
	}

	if (/^Certificate:/ or /^Validation:/) {
		print FH "\n";
	}

	if (/^Validation:\s+(Failed.*)$/) {
		$_ =~ s|($1)|<font color=red>$1</font>|;
	}

	if ($type eq ".mft") {
		if (/^.*[0-9]: ([^ ]+) \(hash: .*/) {
			$_ =~ s|($1)|<a href="$1.html">$1</a>|;
		}
	}

	if (/^--$/ or eof()) {
		print FH "</pre>\n";
		print FH "<i>Generated at " . localtime() . " by <a href=\"https://www.rpki-client.org/\">rpki-client</a> on " . hostname() . "</i>\n";
		close(FH);
		$type = "";
		next;
	}

	print FH $_ . "\n";
}
