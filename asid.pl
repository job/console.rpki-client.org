#!/usr/bin/perl
# Copyright (c) 2023-2025 Job Snijders <job@sobornost.net>
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

use v5.36;
use autodie;

use JSON;
use OpenBSD::Pledge;
use OpenBSD::Unveil;
use Sys::Hostname;

my $asid;
my $record;

pledge(qw(cpath rpath wpath unveil)) or die "Unable to pledge: $!";

chdir($ARGV[0]);

unveil(".", "rwc") or die "Unable to unveil: $!";
unveil() or die "Unable to unveil again: $!";

if (!(-d "asid")) {
	mkdir "asid";
}
chdir("asid");

while (<STDIN>) {
	$record = decode_json($_) or die "unable to decode JSON: $!";

	if ($record->{'type'} ne "roa" and
	    $record->{'type'} ne "aspa" and
	    $record->{'type'} ne "router_key") {
		next;
	}

	if ($record->{'type'} eq "roa") {
		$asid = $record->{'vrps'}[0]->{'asid'};
	}
	if ($record->{'type'} eq "aspa") {
		$asid = $record->{'customer_asid'};
	}
	if ($record->{'type'} eq "router_key") {
		$asid = $record->{'subordinate_resources'}[0]->{'asid'};
	}

	if (-e "AS" . $asid . ".html") {
		open(FH, '>>', "AS" . $asid . ".html") or die $!;
	} else {
		open(FH, '>', "AS" . $asid . ".html") or die $!;
		print FH "<a href=\"/\"><img src=\"/console.gif\" border=0></a><br />\n";
		print FH "<i>Generated at " . localtime() . " by <a href=\"https://www.rpki-client.org/\">rpki-client</a> on " . hostname() . ".</i><br /><br />";
		print FH "<style>td { border-bottom: 1px solid grey; }</style>\n";
		print FH "<table>\n<tr><th>Prefixes/Providers</th><th width=20%>asID</th><th>SIA</th></tr>\n";
	}

	print FH "<tr><td><pre>";

	if ($record->{'type'} eq "roa") {
		foreach my $vrp (@{$record->{'vrps'}}) {
			print FH $vrp->{'prefix'} . " maxlen: " . $vrp->{'maxlen'} . "\n";
		}
	}

	if ($record->{'type'} eq "aspa") {
		if (-e "aspa.html") {
			open(AOFH, '>>', "aspa.html") or die $!;
		} else {
			open(AOFH, '>', "aspa.html") or die $!;
			print AOFH "<a href=\"/\"><img src=\"/console.gif\" border=0></a><br />\n";
			print AOFH "<i>Generated at " . localtime() . " by <a href=\"https://www.rpki-client.org/\">rpki-client</a> on " . hostname() . ".</i><br /><br />";
			print AOFH "<style>td { border-bottom: 1px solid grey; }</style>\n";
			print AOFH "<table>\n<tr><th>SIA</th><th width=20%>Customer AS</th><th>Provider Set</th></tr>\n";
		}
		print AOFH "<tr>\n";
		print AOFH "<td valign=top><strong><pre><a href=\"/" . $record->{'file'} . ".html\">" . $record->{'file'} . "</a></pre></strong></td>\n";
		print AOFH "<td valign=top style=\"text-align:center;\"><strong><pre><a href=\"/AS" . $asid . ".html\">AS" . $asid . "</a></pre></strong></td>\n";
		print AOFH "<td><pre>";
		foreach my $pas (@{$record->{'providers'}}) {
			print AOFH "Provider AS: " . $pas . "\n";
			print FH "Provider AS: " . $pas . "\n";
		}
		print AOFH "</pre></td>\n</tr>\n";

		close(AOFH);
	}

	if ($record->{'type'} eq "router_key") {
		if (-e "bgpsec.html") {
			open(BOFH, '>>', "bgpsec.html") or die $!;
		} else {
			open(BOFH, '>', "bgpsec.html") or die $!;
			print BOFH "<a href=\"/\"><img src=\"/console.gif\" border=0></a><br />\n";
			print BOFH "<i>Generated at " . localtime() . " by <a href=\"https://www.rpki-client.org/\">rpki-client</a> on " . hostname() . ".</i><br /><br />";
			print BOFH "<style>td { border-bottom: 1px solid grey; }</style>\n";
			print BOFH "<table>\n<tr><th>SIA</th><th width=20%>ASID</th><th>Subject Key Identifier</th></tr>\n";
		}
		print BOFH "<tr>\n";
		print BOFH "<td valign=top><strong><pre><a href=\"/" . $record->{'file'} . ".html\">" . $record->{'file'} . "</a></pre></strong></td>\n";
		print BOFH "<td valign=top style=\"text-align:center;\"><strong><pre><a href=\"/AS" . $asid . ".html\">AS" . $asid . "</a></pre></strong></td>\n";
		print BOFH "<td><pre>" . $record->{'ski'} . "</pre></td>\n";
		print BOFH "</tr>\n";

		close(BOFH);
	}

	print FH "</pre></td>\n";
	print FH "<td valign=top style=\"text-align:center;\"><strong><pre><a href=\"/AS" . $asid . ".html\">AS" . $asid . "</a></pre></strong></td>\n";
	print FH "<td valign=top><strong><pre><a href=\"/" . $record->{'file'} . ".html\">" . $record->{'file'} . "</a></pre></strong></td>\n</tr>\n";

	close(FH);
}
