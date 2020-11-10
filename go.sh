#!/bin/sh

set -ev

TMPDIR=$(mktemp -d)

LOG=$(doas /usr/bin/time rpki-client -vcj 2>&1 > /dev/zero)

doas mount_mfs -o nosuid,noperm -s 3G -P /var/cache/rpki-client swap $TMPDIR

doas chown -R job $TMPDIR

cat > $TMPDIR/output.log << EOF
$ date
$(date)

$ time doas rpki-client -vcj
$LOG
EOF

# make per object files
cd $TMPDIR
find * -type f -print0 | xargs -P16 -r -0 -n1 -J {} sh -c '/home/job/console.rpki-client.org/rpki_print.pl $0 > $0.html; echo -n .' {}
cd -

cp console.gif $TMPDIR/
cp /var/db/rpki-client/csv $TMPDIR/vrps.cvs
cp /var/db/rpki-client/json $TMPDIR/json.cvs
mv $TMPDIR/output.log.html $TMPDIR/index.html

# make per ASN files
time find * -name '*.roa' -type f -print0 | xargs -r -0 -n1 /home/job/console.rpki-client.org/roa_print.pl

find $TMPDIR -type d -print0 | xargs -0 doas chmod 755
find $TMPDIR -type f -print0 | xargs -0 doas chmod 644
doas chown -R www $TMPDIR

openrsync -rt $TMPDIR/ chloe.sobornost.net:/var/www/htdocs/console.rpki-client.org/

doas umount $TMPDIR
doas rmdir $TMPDIR
