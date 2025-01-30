#!/bin/sh
# Copyright (c) 2020-2025 Job Snijders <job@sobornost.net>
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

set -euxo pipefail

HTDOCS="/var/www/htdocs/console.rpki-client.org"
CACHEDIR="/var/cache/rpki-client"
ASIDDB="${CACHEDIR}/asid"
OUTDIR="/var/db/rpki-client"
RSYNC_CACHEDIR="/var/cache/rpki-client-rsync"
RSYNC_OUTDIR="/var/db/rpki-client-rsync"

WD="$(mktemp -d)"
chmod +rx "${WD}"

LOG_RRDP="$(mktemp -p ${WD} rrdplog.XXXXXXXXXX)"
LOG_RSYNC="$(mktemp -p ${WD} rsynclog.XXXXXXXXXX)"
ASIDWRITER="$(mktemp -p ${WD} asid.XXXXXXXXXX)"

# run the RRDP+rsync and rsync-only instances
(doas rpki-client -coj    -d ${CACHEDIR}       ${OUTDIR}       2>&1 | ts > ${LOG_RRDP})  &
(doas rpki-client -coj -R -d ${RSYNC_CACHEDIR} ${RSYNC_OUTDIR} 2>&1 | ts > ${LOG_RSYNC}) &
wait

doas cp console.gif "${HTDOCS}/"

install asid.pl ${ASIDWRITER}

prep_vp() {
	doas install -m 644 -o www ${OUTDIR}/$1 ${HTDOCS}/rpki.$1
	doas -u www gzip -fkS tmp ${HTDOCS}/rpki.$1
	doas -u www mv ${HTDOCS}/rpki.$1.tmp ${HTDOCS}/rpki.$1.gz
	doas -u www ln -f ${HTDOCS}/rpki.$1 ${HTDOCS}/vrps.$1
	doas -u www ln -f ${HTDOCS}/rpki.$1.gz ${HTDOCS}/vrps.$1.gz
}

prep_vp csv
prep_vp json

cd ${CACHEDIR}/

find * -type d | (cd ${HTDOCS} && xargs doas -u www mkdir -p)

find * -type f \
	| parallel -m "rpki-client -d ${CACHEDIR} -jf {} | jq -c ." \
	| doas -u www tee ${HTDOCS}/dump.json.tmp > /dev/zero
echo '{"type":"metadata","buildmachine":"'$(hostname)'","buildtime":"'$(date +%Y-%m-%dT%H:%M:%SZ)'","objects":'$(cat ${HTDOCS}/dump.json.tmp | wc -l)'}' \
	| doas -u www tee -a ${HTDOCS}/dump.json.tmp

doas -u www mv ${HTDOCS}/dump.json.tmp ${HTDOCS}/dump.json
doas -u www gzip -fkS tmp ${HTDOCS}/dump.json
doas -u www mv ${HTDOCS}/dump.json.tmp ${HTDOCS}/dump.json.gz

pv ${HTDOCS}/dump.json \
	| egrep '"router_key"|"roa"|"aspa"' \
	| doas -u _rpki-client "${ASIDWRITER}" "${CACHEDIR}"

doas rsync -xrtO --chown www --info=progress2 ${ASIDDB}/ ${HTDOCS}/
doas -u _rpki-client rm -rf "${ASIDDB}"

doas rsync -xrtO --chown www --exclude=.rsync --exclude=.rrdp --exclude=.ta --info=progress2 "${CACHEDIR}/" "${HTDOCS}/"

cd "${HTDOCS}/"

sed 1d ${OUTDIR}/csv \
	| sed 's/,[0-9]*$//' | sort | doas -u www tee vrps-rrdp-rsync.csv > /dev/zero
sed 1d ${RSYNC_OUTDIR}/csv \
	| sed 's/,[0-9]*$//' | sort | doas -u www tee vrps-rsync-only.csv > /dev/zero

# make the pretty index page
doas -u www tee index.htm > /dev/zero << EOF
<img border=0 src="/console.gif" />
<br />
<pre>
All validated RPKI payloads observed by this instance are available in <a href="/rpki.csv">csv</a> and <a href="/rpki.json">json</a> format.
A full JSON dump of all currently observed objects in the RPKI: <a href="/dump.json">dump.json</a> (<a href="/dump.json.gz">gzipped</a>).
Archived full copies of the global RPKI: <a href="https://www.rpkiviews.org/">rpkiviews.org</a>.

For example, you can view all VRPs related to AS 8283 at <a href="/AS8283.html">/AS8283.html</a>.
You can substitute the digits in the above URL with any ASN referenced as asID.

Listings of all currently valid <a href="/aspa.html">ASPA</a> objects and <a href="/bgpsec.html">BGPSec</a> router keys.

Trust Anchors:
<a href="/ta/afrinic/AfriNIC.cer.html">/ta/afrinic/AfriNIC.cer</a>
<a href="/ta/apnic/apnic-rpki-root-iana-origin.cer.html">/ta/apnic/apnic-rpki-root-iana-origin.cer</a>
<a href="/ta/arin/arin-rpki-ta.cer.html">/ta/arin/arin-rpki-ta.cer</a>
<a href="/ta/lacnic/rta-lacnic-rpki.cer.html">/ta/lacnic/lacnic-rpki.cer</a>
<a href="/ta/ripe/ripe-ncc-ta.cer.html">/ta/ripe/ripe-ncc-ta.cer</a>

<strong>Note:</strong> <i>rpki-client outputs information about errorenous objects and problems with repositories.
Any errors in the below log should be solved by CA operators!</i>

<strong># TZ=Etc/UTC rpki-client -c -j</strong>
$(cat ${LOG_RRDP})

<strong># TZ=Etc/UTC rpki-client -R -c -j</strong>
$(cat ${LOG_RSYNC})

<strong># wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv</strong>
$(wc -l vrps-rrdp-rsync.csv vrps-rsync-only.csv)

<strong># comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv</strong>
$(comm -3 vrps-rrdp-rsync.csv vrps-rsync-only.csv)
</pre>
<br />
<i>Generated at $(date) by <a href="https://www.rpki-client.org/">rpki-client</a>.</i>
<br />
<i>Contact: job@openbsd.org</i>
EOF

# cleanup
rm -rf "${WD}"
