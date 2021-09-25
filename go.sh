#!/bin/sh
# Copyright (c) 2020-2021 Job Snijders <job@sobornost.net>
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

set -ev

LOG_RRDP=$(doas /usr/bin/time rpki-client -coj 2>&1 | ts) &
LOG_RSYNC=$(doas /usr/bin/time rpki-client -coj -R -d /var/cache/rpki-client-rsync /var/db/rpki-client-rsync 2>&1 | ts)

TMPDIR=$(mktemp -d)
doas mount_mfs -o nosuid,noperm -s 10G -P /var/cache/rpki-client-rsync swap "${TMPDIR}"
doas chown -R job "${TMPDIR}"
cd "${TMPDIR}"

# make a html file for each ASN with all the ROAs referencing that ASID
(cd rsync && find * -type f -name '*.roa' -print0 | xargs -r -0 -n1 /home/job/console.rpki-client.org/roa_print.pl) &

# Make HTML for all objects, this is slow...
find * -type f ! -name '*.html' -print0 | xargs -P18 -r -0 -n1 -J {} sh -c '/home/job/console.rpki-client.org/rpki_print.pl $0 > $0.html; echo -n .' {}

wait

sed 1d /var/db/rpki-client-rsync/csv | sed 's/,[0-9]*$//' | sort > "${TMPDIR}/vrps-rsync-only.csv"
sed 1d /var/db/rpki-client/csv | sed 's/,[0-9]*$//' | sort > "${TMPDIR}/vrps-rrdp-rsync.csv"

# make the pretty index page
cat > "${TMPDIR}/output.log" << EOF
# time rpki-client -c -j
${LOG_RRDP}

# time rpki-client -R -c -j
${LOG_RSYNC}

# wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv
$(cd "${TMPDIR}" && wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv)

# comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv
$(cd "${TMPDIR}" && comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv)
EOF

/home/job/console.rpki-client.org/rpki_print.pl "${TMPDIR}/output.log" > "${TMPDIR}/index.html"
cp /home/job/console.rpki-client.org/console.gif "${TMPDIR}/"

wait

cd "${TMPDIR}"
find . -type d -print0 | xargs -0 doas chmod 755
find . -type f -print0 | xargs -0 doas chmod 644
cp -rf . /var/www/htdocs/console.rpki-client.org/

# cleanup
cd /
doas umount $TMPDIR
doas rmdir $TMPDIR
