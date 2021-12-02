#!/usr/bin/perl
# Copyright (c) 2020-2021 Job Snijders <job@sobornost.net>
# Copyright (c) 2020 Robert van der Meulen <rvdm@rvdm.net>
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
#
# Utility to create HTML which maps asIDs to ROAs

use strict;
use warnings;
use File::Basename;

my $asn = $ARGV[0];
my $date = localtime();
my @roas = glob( $asn . '/*' ) or die "Cannot open directory: $!";

# get all output from test-roa. This is done in a single pass.
sub get_roainfo {
	my $roa = shift;

	my $roainfo;
	$roainfo->{'asid'} = $asn;

	open(my $f, '<', $roa) or die "Can't open $roa: $!\n";
	while(<$f>) {
		chomp;
		if (/^Subject key identifier: /) {
			s/Subject key identifier: //;
			$roainfo->{'ski'} = $_;
		} elsif (/^File: \.\//) {
			s/^File: ..//;
			$roainfo->{'sia'} = $_;
		} elsif (/^Authority key identifier:/) {
			s/Authority key identifier: //;
			$roainfo->{'aki'} = $_;
		} elsif (/^\s*([0-9]*:.*)/) {
			$roainfo->{'prefixes'} .= $1 . "\n";
		}
	}
	close($f);

	return $roainfo;
}

sub write_html {
        my $roainfo = shift;

	my $html;
	my $header;
	my $fh;
	my $fh2;
	my $htmlfp = "../AS" . $roainfo->{'asid'} . ".html";
	my $allfp = "../" . $roainfo->{'asid'} . ".all.html";

	$header = '<a href="/"><img src="/console.gif" border=0></a><br />' . "\n";
	$header .= '<i>Generated at '. $date . ' by <a href="https://www.rpki-client.org/">rpki-client</a>.</i><br /><br />' . "\n";
	$header .= '<style>td { border-bottom: 1px solid grey; }</styLE>' . "\n";
	$header .= '<table>' . "\n";
	$header .= '<tr><th>Prefixes</th><th width=20%>asID</th><th>SIA</th></tr>'. "\n";

	if (-e $htmlfp) {
		open($fh, '>>', $htmlfp) or die $!;
	} else {
		open($fh, '>', $htmlfp) or die $!;
		print $fh $header;
	}

	if (-e $allfp) {
		open($fh2, '>>', $allfp) or die $!;
	} else {
		open($fh2, '>', $allfp) or die $!;
	}

	$html .= "<tr>\n";
	$html .= "<td><pre>$roainfo->{'prefixes'}</pre></td>\n";
	$html .= '<td valign=top style="text-align:center;"><strong><pre><a href="/AS' . $roainfo->{'asid'} . '.html">AS' . $roainfo->{'asid'} . '</a></pre></strong></td>'."\n";
	$html .= '<td valign=top><strong><pre><a href="/rsync/' . $roainfo->{'sia'} . '.html">' . $roainfo->{'sia'} . '</a></pre></strong></td>' . "\n";
	$html .= "</tr>\n";

	print $fh $html;
	close $fh;
	print $fh2 $html;
	close $fh2;
}

foreach ( @roas ) {
	write_html (get_roainfo $_);
}
