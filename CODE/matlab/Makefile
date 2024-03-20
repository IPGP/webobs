# make arch=32|64|mac target
PATH := $(PATH):/sbin
MCC32 := /usr/local/MATLAB/R2011b/bin/mcc
MCC64 := /usr/local/MATLAB/R2011b/bin/mcc
MCCmac := /Applications/MATLAB_R2011b.app/bin/mcc
OPT32 := -glnx86
SRC := .
TMP := /tmp/mcc

allprocs: genplot gnss meteo waters afm jerk hypomap tremblemaps extenso naqssohplot music3c tilt volcgas raingauge helicorder rsam sara mc3stats
allmaps: locastat gridmaps gnss hypomap tremblemaps extenso tilt rsam
all: locastat gridmaps sefran3 allprocs clean

MCC = $(MCC$(arch))
OUT32 = ../bin/linux-32
OUT64 = ../bin/linux-64
OUTmac = ../bin/maci-64
OPT = $(OPT$(arch))
OUT = $(OUT$(arch))

clean:

%: $(SRC)/superprocs/%.m
	mkdir -p $(TMP)
	$(MCC) $(OPT) -m -R -nodisplay -d $(TMP) $<
	mv -f $(TMP)/$(@F) $(OUT)/
	chmod -R a+x $(OUT)/*$@*
