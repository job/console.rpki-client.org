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

my $data;
my $json;

while (<>) {
	$json .= $_;
	if (/^}$/ or eof()) {
		$data = decode_json($json);
		open(FH, '>', $data->{'file'} . ".json") or die $!;
		print FH $json;
		close(FH);
		$json = "";
	}
}
