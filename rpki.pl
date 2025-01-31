#!/bin/perl
# Copyright (c) 2022-2025 Job Snijders <job@sobornost.net>
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

use v5.38;

use File::Basename;

my $obj;
my $name;
my $path;
my $type;

if (!($ENV{'REQUEST_URI'} =~ /\.(html|json)$/)) {
	print "Status: 403\n\n";
	exit;
}

chdir "/htdocs/console.rpki-client.org/" or die "Dir not found";

$obj = substr $ENV{'REQUEST_URI'}, 1, -5;
if (!(-e $obj)) {
	print "Status: 404\n\n";
	exit;
}

if ($ENV{'REQUEST_URI'} =~ /\.json$/) {
	print "Content-Type: application/json;\n\n";
	print `/bin/rpki-client -d . -jf '$obj'`;
	exit;
}

($name, $path, $type) = fileparse($obj, qr/\.[^.]*/);

print "Content-Type: text/html;\n\n";

print "<img border=0 src='/console.gif' /><br />\n";

foreach (`/bin/rpki-client -d . -vvf '$obj'`) {
	if (/^File: +(.*)$/) {
		print "<h3>";
		if    ($type eq ".mft") { print "Manifest"; }
		elsif ($type eq ".roa") { print "Route Origin Authorization"; }
		elsif ($type eq ".crl") { print "Certificate Revocation List"; }
		elsif ($type eq ".gbr") { print "Ghostbusters Record"; }
		elsif ($type eq ".asa") { print "Autonomous System Provider Authorization"; }
		elsif ($type eq ".cer") { print "Certificate"; }
		elsif ($type eq ".tak") { print "Trust Anchor Key"; }
		print "</h3>\n<pre>\n";
		print '$ <strong>rpki-client -vvf ' . $path . $name . $type . "</strong>\n";
		$_ =~ s|($1)$|$name$type (<a href="$name$type">raw</a>, <a href="$name$type.json">json</a>)|;
	}

	if (/rsync:\/\/(.*)$/ and /[a-z]$/) {
		$_ =~ s|rsync://(.*)$|rsync://<a href="/$1.html">$1</a>|;
	} elsif (/rsync:\/\/(.*)$/) {
		$_ =~ s|rsync://(.*)$|rsync://<a href="/$1">$1</a>|;
	}

	if ($type eq ".roa" and /^asID: +(.*)$/) {
		$_ =~ s|($1)$|<a href="/AS$1.html">$1</a>|;
	}
	elsif ($type eq ".asa" and /^Customer AS: +(.*)$/) {
		$_ =~ s|($1)$|<a href="/AS$1.html">$1</a>|;
	}
	elsif ($type eq ".mft") {
		if (/^.*[0-9]: ([^ ]+) \(hash: .*/) {
			$_ =~ s|($1)|<a href="$1.html">$1</a>|;
		}
	}

	if (/^Validation:\s+(Failed.*)$/) {
		$_ =~ s|($1)|<strong><font color=red>$1</font></strong>|;
	}
	elsif (/^Validation:\s+(OK)$/) {
		$_ =~ s|($1)|<strong><font color=green>$1</font></strong>|;
	}

	if (/^Certificate:/) {
		print "\n";
	}

	print $_;
}

print "</pre>\n";
print "<i>Generated at " . localtime() . " by <a href=\"https://www.rpki-client.org/\">rpki-client</a></i>\n";
