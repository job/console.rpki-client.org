#!/usr/bin/env python3

import json
import sys
import time

nonfunc_cas = {}

with open('/var/db/rpki-client/json') as f:
	d = json.load(f)

for nca in d['nonfunc_cas']:
	nca['since'] = int(time.time())
	nonfunc_cas[nca['location']] = nca

prev = {}

try:
	state = open("/var/www/htdocs/console.rpki-client.org/ca_state.txt", 'r')
	stl = state.readlines()
except FileNotFoundError:
	stl = []

for line in stl:
	ca, since, mft, ski = line.split(" ")
	if ca in nonfunc_cas.keys():
		nonfunc_cas[ca]['since'] = int(since)

new_state = open("/tmp/ca_state_v2.txt", 'w')

for key in nonfunc_cas:
	ca = nonfunc_cas[key]
	new_state.write("{} {} {} {}\n".format(ca['location'], ca['since'], ca['rpkiManifest'], ca['ski']))

new_state.close()
