#!/usr/bin/python

import sys, platform, os, pwd, re, time
from pyWebObs.Config import WEBOBS, OWNERS
from pyWebObs.Grids import GRIDS

# dump WEBOBS hash -----------------------------------------------------------
def dwebobs(op=None):
	for key,val in WEBOBS.items():
		if op is None or re.match(op,key): print key+" => "+val

# dump OWNERS hash -----------------------------------------------------------
def downers(*op):
	for key,val in OWNERS.items():
		print key+" => "+val

# dump GRIDS hash -----------------------------------------------------------
def dgrids(*op):
	for key,val in GRIDS.items():
		print key+" => "+val

# quit -----------------------------------------------------------------------
def bye(*op):
	print "Bye.\n" 
	sys.exit()

# help -----------------------------------------------------------------------
def dhelp(*op):
	for k in sorted(vectors,key=lambda v: vectors[v]['seq']):
		print vectors[k]['help']
		
# sys ------------------------------------------------------------------------
def dsys(*op):
	print "%s on %s (%s)" % (platform.platform(aliased=1,terse=1),platform.node(),platform.machine())
	print "Python %s - version %s" % (platform.python_implementation(), platform.python_version())
	print "Python path: %s" % sys.path
	if 'TZ' in os.environ:
		print "env TZ = %s" % os.environ['TZ']
	else: print "env TZ not defined"
	print "time.tzname=%s,%s" % time.tzname
	print "PID %d started %d by %s (%d/%d) in %s" % (os.getpid(), time.time(), pwd.getpwuid(os.getuid())[0], os.getuid(), os.getgid(), os.getcwd())
	if 'GATEWAY_INTERFACE' in os.environ:
		pass

	
# vectors to supported commands ----------------------------------------------
vectors = {
		'WEBOBS'    :  {'addr' : dwebobs,   'seq' :  10,   'help' : 'WEBOBS [key]    : dump WEBOBS key or all'},
		'GRIDS'     :  {'addr' : dgrids,    'seq' :  15,   'help' : 'GRIDS  [key]    : dump GRIDS key or all'},
		'OWNERS'    :  {'addr' : downers,   'seq' :  20,   'help' : 'OWNERS          : dump OWNERS'},
		'sys'       :  {'addr' : dsys,      'seq' : 100,   'help' : 'sys             : print system information'},
		'help'      :  {'addr' : dhelp,     'seq' : 150,   'help' : 'help            : this help list'},
		'quit'      :  {'addr' : bye,       'seq' : 200,   'help' : 'quit            : make a guess !' }
}                                           

# woc batch if arguments on command line -------------------------------------
# interpret/execute these args as a single woc command and quit --------------
if len(sys.argv) > 1:
	vectors[sys.argv[1]]['addr'](" ".join(sys.argv[2:]))
	sys.exit()

# woc interactive, Read Evaluate Process Woc Command -------------------------
while 1:
	try:
		line = raw_input("WOC> ")
		cmd = line.split()
	except KeyboardInterrupt:
		break
	if not cmd:
		continue
	try:
		vectors[cmd[0]]['addr'](" ".join(cmd[1:]))
	except KeyError:
		print "Oops...\n"
		dhelp()
	
# End Read Evaluate Process Woc Command ---------------------------------------

