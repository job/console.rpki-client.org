#!/usr/bin/perl
#
# Utility to generate HTML from RPKI data
#
# Job Snijders <job@openbsd.org>
# Robert van der Meulen <rvdm@rvdm.net>

use strict;
use warnings;
use Data::Dumper;
use File::Basename;

my $tals = "/etc/rpki/*.tal";
my $openssl = "/usr/bin/openssl";
my $testtal = "/usr/local/bin/test-tal";
my $testcert = "/usr/local/bin/test-cert";
my $testroa = "/usr/local/bin/test-roa";
my $testmft = "/usr/local/bin/test-mft";
my $testgbr = "/usr/local/bin/test-gbr";

# template locations
my $index_template = "/home/job/console.rpki-client.org/templates/index.html";
my $roa_template = "/home/job/console.rpki-client.org/templates/roa.html";
my $mft_template = "/home/job/console.rpki-client.org/templates/manifest.html";
my $cert_template = "/home/job/console.rpki-client.org/templates/certificate.html";
my $crl_template = "/home/job/console.rpki-client.org/templates/crl.html";
my $gbr_template = "/home/job/console.rpki-client.org/templates/gbr.html";

my @talfiles = glob($tals);

my @suffixes = ('cer', 'gbr', 'crl', 'mft', 'roa', 'log');
my ($filepath, $dir, $type) = fileparse($ARGV[0], @suffixes);

my $date = localtime();

####
# ROA file processing stuff
####

# get all output from test-roa. This is done in a single pass.
sub get_roainfo {
	my $roa = shift;

	my $roainfo;

	# Pipe the PEM encoded EE certificate through openssl
	open(my $CMD, "-|", "$testroa -p $roa | $openssl x509 -text") or die "Can't run $openssl: $!\n";
	while(<$CMD>) {
		chomp;
		$roainfo->{'cert'} .= $_ . "\n";
		if (/\s*CA Issuers - URI:rsync:\/\/(.*\.cer)$/) {
			$roainfo->{'aia'} = $1;
		}
		if (/\s*Signed Object - URI:rsync:\/\/(.*)/) {
			$roainfo->{'sia'} = $1;
		}
	}
	close($CMD);

	open($CMD, '-|', "$testroa -v $roa") or die "Can't run $testroa: $!\n";
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
		} elsif (/^\s*[0-9]*:/) {
			$roainfo->{'prefixes'} .= $_ . "\n";
		}
	}
	close($CMD);

	return $roainfo;
}

sub print_roa {
        my $roainfo = shift;

        my $templatedata = get_template($roa_template);

        $templatedata =~ s/{sia}/$roainfo->{'sia'}/g;
        $templatedata =~ s/{ski}/$roainfo->{'ski'}/g;
        $templatedata =~ s/{aki}/$roainfo->{'aki'}/g;
        $templatedata =~ s/{aia}/$roainfo->{'aia'}/g;
        $templatedata =~ s/{asid}/$roainfo->{'asid'}/g;
        $templatedata =~ s/{prefixes}/$roainfo->{'prefixes'}/g;
        $templatedata =~ s/{cert}/$roainfo->{'cert'}/g;
        $templatedata =~ s/{date}/$date/g;

        print $templatedata;
}

####
# CRL
####

sub get_crlinfo {
	my $crl = shift;

	my $crlinfo;
	$crlinfo->{'sia'} = $crl;
	$crlinfo->{'aia'} = $crl;
	$crlinfo->{'aia'} =~ s/.crl/.mft/;

	# Pipe the PEM encoded EE certificate through openssl
	open(my $CMD, "-|", "$openssl crl -in $crl -inform DER -text") or die "Can't run $openssl: $!\n";
	while(<$CMD>) {
		chomp;
		if (/(\s*keyid:)(.*)$/) {
			$crlinfo->{'aki'} = $2;
			$_ = "$1<a href=\"/$crlinfo->{'aia'}.html\">$2</a>";
		}
		$crlinfo->{'crl'} .= $_ . "\n";
	}
	close($CMD);

	return $crlinfo;
}

sub print_crl {
        my $crlinfo = shift;

        my $templatedata = get_template($crl_template);

        $templatedata =~ s/{sia}/$crlinfo->{'sia'}/g;
        $templatedata =~ s/{aia}/$crlinfo->{'aia'}/g;
        $templatedata =~ s/{aki}/$crlinfo->{'aki'}/g;
        $templatedata =~ s/{crl}/$crlinfo->{'crl'}/g;
        $templatedata =~ s/{date}/$date/g;

        print $templatedata;
}

####
# CRL
####

sub get_gbrinfo {
	my $gbr = shift;

	my $gbrinfo;
	$gbrinfo->{'sia'} = substr $gbr, 6;

	# Pipe the CMS through openssl to extract the eContent
	open(my $CMD, "-|", "$openssl cms -verify -noverify -in $gbr -inform DER -signer $gbr.pem") or die "Can't run $openssl: $!\n";
	while(<$CMD>) {
		chomp;
		if (!/Verification successful/) {
			$gbrinfo->{'gbr'} .= $_ . "\n";
		}
	}
	close($CMD);

	# Pipe the PEM encoded EE certificate through openssl
	open($CMD, "-|", "$openssl x509 -in $gbr.pem -text") or die "Can't run $openssl: $!\n";
	while(<$CMD>) {
		chomp;
		$gbrinfo->{'gbrcert'} .= $_ . "\n";
	}
	close($CMD);

	# extract AIA, AKI, SKI
	open($CMD, '-|', "$testgbr -v $gbr") or die "Can't run $testgbr: $!\n";
	while(<$CMD>) {
		chomp;
		if (/^Subject key identifier: /) {
			s/Subject key identifier: //;
			$gbrinfo->{'ski'} = $_;
		} elsif (/^Authority key identifier:/) {
			s/Authority key identifier: //;
			$gbrinfo->{'aki'} = $_;
		} elsif (/^Authority info access: rsync:\/\/(.*)/) {
			$gbrinfo->{'aia'} = $1;
		}
	}
	close($CMD);


	return $gbrinfo;
}

sub print_gbr {
        my $gbrinfo = shift;

        my $templatedata = get_template($gbr_template);

        $templatedata =~ s/{ski}/$gbrinfo->{'ski'}/g;
        $templatedata =~ s/{sia}/$gbrinfo->{'sia'}/g;
        $templatedata =~ s/{aki}/$gbrinfo->{'aki'}/g;
        $templatedata =~ s/{aia}/$gbrinfo->{'aia'}/g;
        $templatedata =~ s/{gbr}/$gbrinfo->{'gbr'}/g;
        $templatedata =~ s/{gbrcert}/$gbrinfo->{'gbrcert'}/g;
        $templatedata =~ s/{date}/$date/g;

        print $templatedata;
}


####
# Manifest file processing
####

# get all output from test-roa. This is done in a single pass.
sub get_mftinfo {
	my $mft = shift;

	my $mftinfo;

	# Pipe the PEM encoded EE certificate through openssl
	open(my $CMD, "-|", "$testmft -p $mft | $openssl x509 -text") or die "Can't run $openssl: $!\n";
	while(<$CMD>) {
		chomp;
		$mftinfo->{'cert'} .= $_ . "\n";
		if (/\s*CA Issuers - URI:rsync:\/\/(.*\.cer)$/) {
			$mftinfo->{'aia'} = $1;
		}
		if (/\s*Signed Object - URI:rsync:\/\/(.*)/) {
			$mftinfo->{'sia'} = $1;
		}
	}
	close($CMD);

	open($CMD, '-|', "$testmft -v $mft") or die "Can't run $testmft: $!\n";
	while(<$CMD>) {
		chomp;
		if (/^Subject key identifier: /) {
			s/Subject key identifier: //;
			$mftinfo->{'ski'} = $_;
		} elsif (/^Authority key identifier:/) {
			s/Authority key identifier: //;
			$mftinfo->{'aki'} = $_;
		} elsif (/^Manifest Number:/) {
			s/Manifest Number: //;
			$mftinfo->{'seqnum'} = $_;
		} elsif (/(^\s*[0-9]*:) (.*)/) {
			$mftinfo->{'files'} .= "$1 <a href=\"$2.html\">$2</a>\n";
		} elsif (/^\s*hash /) {
			$mftinfo->{'files'} .= $_ . "\n";
		}
	}
	close($CMD);

	return $mftinfo;
}

####
# Manifest handling
####

sub print_mft {
        my $mftinfo = shift;

        my $templatedata = get_template($mft_template);

        $templatedata =~ s/{sia}/$mftinfo->{'sia'}/g;
        $templatedata =~ s/{ski}/$mftinfo->{'ski'}/g;
        $templatedata =~ s/{aki}/$mftinfo->{'aki'}/g;
        $templatedata =~ s/{aia}/$mftinfo->{'aia'}/g;
        $templatedata =~ s/{seqnum}/$mftinfo->{'seqnum'}/g;
        $templatedata =~ s/{files}/$mftinfo->{'files'}/g;
        $templatedata =~ s/{cert}/$mftinfo->{'cert'}/g;
        $templatedata =~ s/{date}/$date/g;

        print $templatedata;
}

# template
sub get_template {
	my $template = shift;
	
	open my $fh, '<', $template or die "Can't open $template: $!\n";
	my $tmp = $/;
	$/ = undef;
	my $templatedata = <$fh>;
	close $fh;
	$/ = $tmp;

	return $templatedata;
}

# produces index.html based on output.log
sub write_index {
	my $log = shift;
	my $logoutput;
	my $taindex;
        my $templatedata = get_template($index_template);

	open(my $fh, '<', $log) or die "cannot open file $log";
	{
		local $/;
		$logoutput = <$fh>;
	}
	close($fh);

	foreach my $tal (@talfiles) {
		my $tashort;
		my @taname;
		@taname = split('/', $tal);
		$tashort = substr "$taname[3]", 0, -4;
		open($fh, '-|', "test-tal -v $tal");
		while(<$fh>) {
			chomp;
			if (/.* URI: rsync:\/\/(.*)/) {
				my $fname = fileparse($1);
				$taindex .= "<a href=\"/ta/$tashort/" . $fname . ".html\">rsync://$1</a>\n";

			}
		}
		close($fh)
	}

        $templatedata =~ s/{tals}/$taindex/g;
        $templatedata =~ s/{date}/$date/g;
        $templatedata =~ s/{log}/$logoutput/g;
        print $templatedata;
}

sub get_tal_from_filepath {
	my $path = shift;
	my @talname = split('/', $path);
 
	return "/etc/rpki/" . $talname[1] . ".tal";
	die "get_tal_from_filepath problem\n";
}

####
# Certificates
####

sub get_certinfo {
	my $cert = shift;

	my $certinfo;
	my $talfile;
	$certinfo->{'sia'} = $cert;
	$certinfo->{'notifyurl'} = '';

	if ($cert =~ /^ta\//) {
		$certinfo->{'root'} = 'Root ';
	} else {
		$certinfo->{'root'} = '';
	}

	# Pipe the PEM encoded EE certificate through openssl
	open(my $CMD, "-|", "$openssl x509 -in $cert -inform DER -text") or die "Can't run $openssl: $!\n";
	while(<$CMD>) {
		chomp;
		$certinfo->{'cert'} .= $_ . "\n";
	}
	close($CMD);

	if ($certinfo->{'root'} eq 'Root ') {
		$talfile = get_tal_from_filepath($certinfo->{'sia'});
		open($CMD, "-|", "test-cert -vt $cert $talfile") or die "Can't run: $!\n";
	} else {
		open($CMD, "-|", "test-cert -v $cert") or die "Can't run: $!\n";
	}
	while(<$CMD>) {
		chomp;
		if (/^Subject key identifier: (.*)/) {
			$certinfo->{'ski'} = $1;
		} elsif (/^Authority key identifier: (.*)/) {
			$certinfo->{'aki'} = $1;
		} elsif (/^Authority info access: rsync:\/\/(.*)/) {
			$certinfo->{'aia'} = $1;
		} elsif (/^Manifest: rsync:\/\/(.*)/) {
			$certinfo->{'manifest'} = $1;
		} elsif (/^Revocation list: (.*)/) {
			$certinfo->{'crl'} = $1;
		} elsif (/^caRepository: rsync:\/\/(.*)/) {
			$certinfo->{'carepository'} = $1;
		} elsif (/^Notify URL: (.*)/) {
			$certinfo->{'notifyurl'} = $1;
		} elsif (/\s+(.*)/) {
			$certinfo->{'resources'} .= "    " . $1 . "\n";
		}
	}
	close($CMD);

	return $certinfo;
}

sub print_cert {
        my $certinfo = shift;

        my $templatedata = get_template($cert_template);

        $templatedata =~ s/{root}/$certinfo->{'root'}/g;
        $templatedata =~ s/{ski}/$certinfo->{'ski'}/g;
	if ($certinfo->{'root'}) {
		$templatedata =~ s/{aia}/index/g;
		$templatedata =~ s/{aki}/Trust Anchor/g;
	} else {
		$templatedata =~ s/{aia}/$certinfo->{'aia'}/g;
		$templatedata =~ s/{aki}/$certinfo->{'aki'}/g;
	}
	$templatedata =~ s/{sia}/$certinfo->{'sia'}/g;
        $templatedata =~ s/{manifest}/$certinfo->{'manifest'}/g;
        $templatedata =~ s/{notifyurl}/$certinfo->{'notifyurl'}/g;
        $templatedata =~ s/{carepository}/$certinfo->{'carepository'}/g;
        $templatedata =~ s/{crl}/$certinfo->{'crl'}/g;
        $templatedata =~ s/{resources}/$certinfo->{'resources'}/g;
        $templatedata =~ s/{cert}/$certinfo->{'cert'}/g;
        $templatedata =~ s/{date}/$date/g;

        print $templatedata;
}

if ($type eq 'roa') {
	print_roa (get_roainfo $ARGV[0]);
} elsif ($type eq 'log') {
	write_index $ARGV[0];
} elsif ($type eq 'mft') {
	print_mft (get_mftinfo $ARGV[0]);
} elsif ($type eq 'crl') {
	print_crl (get_crlinfo $ARGV[0]);
} elsif ($type eq 'cer') {
	print_cert (get_certinfo $ARGV[0]);
} elsif ($type eq 'gbr') {
	print_gbr (get_gbrinfo $ARGV[0]);
} else {
	print "Needs a filename as arguments";
}
