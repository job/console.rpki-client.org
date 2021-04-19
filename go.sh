#!/bin/sh

set -ev

TMPDIR=$(doas rm -rf /tmp/rrdp; mktemp -d)

[ -d /var/cache/rpki-client/rrdp ] && doas mv /var/cache/rpki-client/rrdp /tmp

LOG=$(doas /usr/bin/time rpki-client -R -v -c -j 2>&1 | ts)

doas mount_mfs -o nosuid,noperm -s 5G -P /var/cache/rpki-client swap $TMPDIR

doas chown -R job $TMPDIR

# make per-ASN html file based on ROA data
(cd "${TMPDIR}/rsync/" && find * -type f -name '*.roa' -print0 | xargs -r -0 -n1 /home/job/console.rpki-client.org/roa_print.pl) &

# make per object files
cd "${TMPDIR}/"
find * -type f ! -name '*.html' -print0 | xargs -P16 -r -0 -n1 -J {} sh -c '/home/job/console.rpki-client.org/rpki_print.pl $0 > $0.html; echo -n .' {}
cd -

wait

sed 1d /var/db/rpki-client/csv | sort > "${TMPDIR}/vrps-rsync-only.csv"

cp /var/db/rpki-client/csv "${TMPDIR}/vrps.csv"
cp /var/db/rpki-client/json "${TMPDIR}/vrps.json"

cd "${TMPDIR}/" && tar cfj - . | ssh chloe.sobornost.net 'cd /var/www/htdocs/console.rpki-client.org/ && tar xfj -'

[ -d /var/cache/rpki-client/rsync ] && doas rm -rf /var/cache/rpki-client/rsync

[ -d /tmp/rrdp ] && doas mv /tmp/rrdp /var/cache/rpki-client

LOG_RRDP=$(doas /usr/bin/time rpki-client -r -v -j -c 2>&1 | ts)

sed 1d /var/db/rpki-client/csv | sort > "${TMPDIR}/vrps-rrdp-rsync.csv"

cat > $TMPDIR/output.log << EOF
# date
$(date)

# time rpki-client -R -v -j -c
${LOG}

# time rpki-client -r -v -j -c
${LOG_RRDP}

# wc -l vrps-rsync-only.csv vrps-rrdp-rsync.csv
$(wc -l vrps-rsync-only.csv vrps-rrdp-rsync.csv)

# comm -3 vrps-rsync-only.csv vrps-rrdp-rsync.csv
$(comm -3 vrps-rsync-only.csv vrps-rrdp-rsync.csv)
EOF

/home/job/console.rpki-client.org/rpki_print.pl "${TMPDIR}/output.log" > "${TMPDIR}/index.html"

cp /home/job/console.rpki-client.org/console.gif "${TMPDIR}/"

wait

find "${TMPDIR}" -type d -print0 | xargs -0 doas chmod 755
find "${TMPDIR}" -type f -print0 | xargs -0 doas chmod 644

# given the nature of the file and directory layout, using tar
# over ssh is perhaps faster than using rsync
cd "${TMPDIR}/" && tar cfj - . | ssh chloe.sobornost.net 'cd /var/www/htdocs/console.rpki-client.org/ && tar xfj -'
cd /
doas umount $TMPDIR
doas rmdir $TMPDIR
