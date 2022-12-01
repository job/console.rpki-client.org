#!/bin/sh
# Copyright (c) 2020-2022 Job Snijders <job@sobornost.net>
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

HTMLWRITER="/tmp/html.pl"
HTDOCS="/var/www/htdocs/console.rpki-client.org"
CACHEDIR="/var/cache/rpki-client-rsync"
OUTDIR="/var/db/rpki-client-rsync"

LOG_RRDP=$(mktemp)
LOG_RSYNC=$(mktemp)

FILELIST=$(mktemp)
ODDLIST=$(mktemp)
EVENLIST=$(mktemp)

cp console.gif "${HTDOCS}/"
cp html.pl ${HTMLWRITER}

(doas rpki-client -coj 2>&1 | ts > ${LOG_RRDP}) &
(doas rpki-client -coj -R -d ${CACHEDIR} ${OUTDIR} 2>&1 | ts > ${LOG_RSYNC}) &

wait

cd ${CACHEDIR}

rm -f ${HTDOCS}/dump.json.tmp ${HTDOCS}/dump.json.tmp2
find * -type f -not -name '*.html' > ${FILELIST}
sed -n 'p;n' ${FILELIST} > ${ODDLIST}
sed -n 'n;p' ${FILELIST} > ${EVENLIST}

(cat ${ODDLIST} | xargs rpki-client -d ${CACHEDIR} -vvf | doas -u _rpki-client ${HTMLWRITER}) &
(cat ${EVENLIST} | xargs rpki-client -d ${CACHEDIR} -vvf | doas -u _rpki-client ${HTMLWRITER}) &
(cat ${ODDLIST} | xargs rpki-client -d ${CACHEDIR} -j -f | jq -c '.' > ${HTDOCS}/dump.json.tmp) &
(cat ${EVENLIST} | xargs rpki-client -d ${CACHEDIR} -j -f | jq -c '.' > ${HTDOCS}/dump.json.tmp2) &

wait

rsync -xrt --info=progress2 * ${HTDOCS}
doas find * -type f -name '*.html' -delete

cat ${HTDOCS}/dump.json.tmp2 >> ${HTDOCS}/dump.json.tmp && rm ${HTDOCS}/dump.json.tmp2
rm -f ${HTDOCS}/dump.json.tmp.gz && gzip -k ${HTDOCS}/dump.json.tmp
mv ${HTDOCS}/dump.json.tmp ${HTDOCS}/dump.json
mv ${HTDOCS}/dump.json.tmp.gz ${HTDOCS}/dump.json.gz
touch ${HTDOCS}/dump.json ${HTDOCS}/dump.json.gz

sed 1d /var/db/rpki-client/csv | sed 's/,[0-9]*$//' | \
	sort > "${HTDOCS}/vrps-rrdp-rsync.csv"
sed 1d ${OUTDIR}/csv | sed 's/,[0-9]*$//' | \
	sort > "${HTDOCS}/vrps-rsync-only.csv"

# make the pretty index page
cat > "${HTDOCS}/index.html" << EOF
<img border=0 src="/console.gif" />
<br />
<pre>
All RPKI VRPs observed by this validator in <a href="/vrps.csv">csv</a> or <a href="/vrps.json">json</a> format.
A full JSON dump of all currently observed objects in the RPKI: <a href="/dump.json">dump.json</a> (<a href="/dump.json.gz">gzipped</a>).
Archived full copies of the global RPKI: <a href="https://www.rpkiviews.org/">rpkiviews.org</a>.

For example, you can view all VRPs related to AS 8283 at <a href="/AS8283.html">/AS8283.html</a>.
You can substitute the digits in the above URL with any ASN referenced as asID.

Trust Anchors:
<a href="/ta/afrinic/AfriNIC.cer.html">/ta/afrinic/AfriNIC.cer</a>
<a href="/ta/apnic/apnic-rpki-root-iana-origin.cer.html">/ta/apnic/apnic-rpki-root-iana-origin.cer</a>
<a href="/ta/arin/arin-rpki-ta.cer.html">/ta/arin/arin-rpki-ta.cer</a>
<a href="/ta/lacnic/rta-lacnic-rpki.cer.html">/ta/lacnic/lacnic-rpki.cer</a>
<a href="/ta/ripe/ripe-ncc-ta.cer.html">/ta/ripe/ripe-ncc-ta.cer</a>

<strong>Note:</strong> <i>rpki-client outputs information about errorenous objects and problems with repositories.
Any errors in the below log should be solved by CA operators!</i>

<strong># rpki-client -c -j</strong>
$(cat ${LOG_RRDP})

<strong># rpki-client -R -c -j</strong>
$(cat ${LOG_RSYNC})

<strong># wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv</strong>
$(cd "${HTDOCS}" && wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv)

<strong># comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv</strong>
$(cd "${HTDOCS}" && comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv)
</pre>
<br />
<i>Generated at $(date) by <a href="https://www.rpki-client.org/">rpki-client</a>.</i>
<br />
<i>Contact: job@openbsd.org</i>
EOF

# cleanup
rm ${LOG_RRDP} ${LOG_RSYNC}
rm ${FILELIST} ${ODDLIST} ${EVENLIST}
rm ${HTMLWRITER}
