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

pledge(qw(cpath rpath wpath unveil)) || die "Unable to pledge: $!";

chdir("/var/www/htdocs/console.rpki-client.org") || die "Unable to chdir: $!";

unveil(".", "rwc") || die "Unable to unveil: $!";
unveil() || die "Unable to unveil again: $!";

my $asid;
my $fn;
my $name;
my $path;
my @roa_ips;
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
		$_ =~ s|($1)$|$name$type (<a href="$name$type">download</a>)|;
	}

	if ($type eq ".roa" and /^asID: +(.*)$/) {
		$_ =~ s|($1)$|<a href="/AS$1.html">$1</a>|;
		$asid = $1;
	}

	if (/rsync:\/\/(.*)$/ and /[a-z]$/) {
		$_ =~ s|rsync://(.*)$|rsync://<a href="/$1.html">$1</a>|;
	} elsif (/rsync:\/\/(.*)$/) {
		$_ =~ s|rsync://(.*)$|rsync://<a href="/$1">$1</a>|;
	}

	if (/^Certificate:/ or /^Validation:/) {
		print FH "\n";
	}

	if ($type eq ".mft") {
		if (/^ +[0-9]+: (.*)$/) {
			$_ =~ s|($1)$|<a href="$1.html">$1</a>|;
		}
	}

	if ($type eq ".roa") {
		if (/^ +[0-9]+: [0-9].*[0-9]$/) {
			push(@roa_ips, $_);
		}
	}

	if (/^--$/ or eof()) {
		if ($type eq ".roa") {
			if (-e "asid/AS" . $asid . ".html") {
				open(ROA, '>>', "asid/AS" . $asid . ".html") or die $!;
			} else {
				open(ROA, '>', "asid/AS" . $asid . ".html") or die $!;
				print ROA "<a href=\"/\"><img src=\"/console.gif\" border=0></a><br />\n";
				print ROA "<i>Generated at " . localtime() . " by <a href=\"https://www.rpki-client.org/\">rpki-client</a>.</i><br /><br />";
				print ROA "<style>td { border-bottom: 1px solid grey; }</style>\n";
				print ROA "<table>\n<tr><th>Prefixes</th><th width=20%>asID</th><th>SIA</th></tr>\n";
			}
			print ROA "<tr><td><pre>";
			foreach (@roa_ips) {
				print ROA "$_\n";
			}
			print ROA "</pre></td>\n";
			print ROA "<td valign=top style=\"text-align:center;\"><strong><pre><a href=\"/AS" . $asid . ".html\">AS" . $asid . "</a></pre></strong></td>\n";
			print ROA "<td valign=top><strong><pre><a href=\"" . $path . $name . $type . ".html\">" . $path . $name . $type . "</a></pre></strong></td>\n</tr>\n";
			close(ROA);
			$asid = "";
			@roa_ips = ();
		}
		print FH "</pre>\n";
		print FH "<i>Generated at " . localtime() . " by <a href=\"https://www.rpki-client.org/\">rpki-client</a>.</i>\n";
		close(FH);
		$type = "";
		next;
	}

	print FH $_ . "\n";
}
