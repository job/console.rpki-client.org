#!/usr/bin/perl
# Copyright (c) 2023 Job Snijders <job@sobornost.net>
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
use JSON;
use OpenBSD::Pledge;
use OpenBSD::Unveil;

pledge(qw(cpath rpath wpath unveil)) || die "Unable to pledge: $!";

chdir("/var/www/htdocs/console.rpki-client.org") || die "Unable to chdir: $!";

unveil(".", "rwc") || die "Unable to unveil: $!";
unveil() || die "Unable to unveil again: $!";

my $asid;
my $record;

while (<>) {
	$record = decode_json($_);

	if ($record->{'type'} ne "roa" and $record->{'type'} ne "aspa") {
		next;
	}

	if ($record->{'type'} eq "roa") {
		$asid = $record->{'vrps'}[0]->{'asid'};
	}
	if ($record->{'type'} eq "aspa") {
		$asid = $record->{'customer_asid'};
	}

	if (-e "asid/AS" . $asid . ".html") {
		open(FH, '>>', "asid/AS" . $asid . ".html") or die $!;
	} else {
		open(FH, '>', "asid/AS" . $asid . ".html") or die $!;
		print FH "<a href=\"/\"><img src=\"/console.gif\" border=0></a><br />\n";
		print FH "<i>Generated at " . localtime() . " by <a href=\"https://www.rpki-client.org/\">rpki-client</a>.</i><br /><br />";
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
		foreach my $aspa (@{$record->{'provider_set'}}) {
			print FH "Provider AS " . $aspa->{'asid'};
			if (exists($aspa->{'afi_limit'})) {
				print FH " (" . $aspa->{'afi_limit'} . " only)";
			}
			print FH "\n";
		}
	}

	print FH "</pre></td>\n";
	print FH "<td valign=top style=\"text-align:center;\"><strong><pre><a href=\"/AS" . $asid . ".html\">AS" . $asid . "</a></pre></strong></td>\n";
	print FH "<td valign=top><strong><pre><a href=\"/" . $record->{'file'} . ".html\">" . $record->{'file'} . "</a></pre></strong></td>\n</tr>\n";

	close(FH);
}
