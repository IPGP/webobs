import re, fcntl
from string import Template

WEBOBS={}
OWNERS={}

def readCfg(fn=None):
	if fn is None: return
	H = {}
	try:
		with open(fn) as RDR:
			fcntl.flock(RDR, fcntl.LOCK_SH)
			for L in RDR:
				L = re.sub(r'(?<!\\)#.*$','',L)
				L = re.sub(r'\\','',L)
				if L[0] == '=': continue
				key,val = L.partition("|")[::2]
				if key.strip() == '': continue
				H[key.strip()] = val.strip()
	except IOError as e:
		print e
		return

	for key,val in H.items():
		H[key] = Template(val).safe_substitute(H)
	for key,val in H.items():
		H[key] = Template(val).safe_substitute(H)
	for key,val in H.items():
		try:
			H[key] = re.sub('[\$]WEBOBS[\{](.*?)[\}]', lambda x: WEBOBS[x.group(1)], val)
		except KeyError, e:
			continue
	return H

WEBOBS=readCfg("/etc/webobs.d/WEBOBS.rc")
OWNERS=readCfg(WEBOBS['FILE_OWNERS'])


