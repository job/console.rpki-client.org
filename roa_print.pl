#!/usr/bin/perl
#
# Utility to generate HTML from RPKI data
#
# Job Snijders <job@openbsd.org>
# Robert van der Meulen <rvdm@rvdm.net>

use strict;
use warnings;
use File::Basename;

my $openssl = "/usr/bin/openssl";
my $testroa = "/usr/local/bin/test-roa";

my ($filepath, $dir) = fileparse($ARGV[0]);

my $date = localtime();

####
# ROA file processing stuff
####

# get all output from test-roa. This is done in a single pass.
sub get_roainfo {
	my $roa = shift;

	my $roainfo;
	$roainfo->{'sia'} = $roa;

	open(my $CMD, '-|', "$testroa -v $roa") or die "Can't run $testroa: $!\n";
	while(<$CMD>) {
		chomp;
		if (/^Subject key identifier: /) {
			s/Subject key identifier: //;
			$roainfo->{'ski'} = $_;
		} elsif (/^Authority key identifier:/) {
			s/Authority key identifier: //;
			$roainfo->{'aki'} = $_;
		} elsif (/^asID:/) {
			s/asID: //;
			$roainfo->{'asid'} = $_;
		} elsif (/^\s*([0-9]*:.*)/) {
			$roainfo->{'prefixes'} .= $1 . "\n";
		}
	}
	close($CMD);

	return $roainfo;
}

sub write_html {
        my $roainfo = shift;
	my $html;
	my $header;
	my $fh;
	my $fh2;
	my $htmlfp = "../AS" . $roainfo->{'asid'} . ".html";

	$header = '<a href="/"><img src="/console.gif" border=0></a><br />' . "\n";
	$header .= '<i>Generated at '. $date . ' by <a href="https://www.rpki-client.org/">rpki-client</a>.</i><br /><br />' . "\n";
	$header .= '<style>td { border-bottom: 1px solid grey; }</styLE>' . "\n";
	$header .= '<table>' . "\n";
	$header .= '<tr><th>SIA</th><th width=20%>asID</th><th>Prefixes</th></tr>'. "\n";

	if (-e $htmlfp) {
		open($fh, '>>', $htmlfp) or die $!;
	} else {
		open($fh, '>', $htmlfp) or die $!;
		print $fh $header;
	}
	if (-e 'roas.html') {
		open($fh2, '>>', 'roas.html') or die $!;
	} else {
		open($fh2, '>', 'roas.html') or die $!;
		print $fh2 $header;
	}
	$html .= "<tr>\n";
	$html .= '<td valign=top><strong><pre><a href="/rsync/' . $roainfo->{'sia'} . '.html">' . $roainfo->{'sia'} . '</a></pre></strong></td>' . "\n";
	$html .= '<td valign=top style="text-align:center;"><strong><pre><a href="/AS' . $roainfo->{'asid'} . '.html">AS' . $roainfo->{'asid'} . '</a></pre></strong></td>'."\n";
	$html .= "<td><pre>$roainfo->{'prefixes'}</pre></td>\n";
	$html .= "</tr>\n";
	print $fh $html;
	close $fh;
	print $fh2 $html;
	close $fh2;
}

write_html (get_roainfo $ARGV[0]);
