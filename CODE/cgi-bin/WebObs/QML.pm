#---------------------------------------------------------------
# ------------------- WEBOBS / IPGP ----------------------------
# QML.pm
# ------
# Perl module to import QuakeML files
#
#
# Authors: François Beauducel <beauducel@ipgp.fr>, Jean-Marie Saurel <saurel@ipgp.fr>
# Created: 2012-04-30
# Updated: 2017-07-20
#--------------------------------------------------------------
use strict;
use WebObs::XML2;

#--------------------------------------------------------------------------------------------------------------------------------------
# qmlvalues: returns origin and magmitude preferred values from XML2 arrayd
sub qmlorigin {
	my $file = $_[0];
	my %qml;

	if (-e $file) {
		my @xml2 = qx($WEBOBS{XML2_PRGM} < $file);

		my $root = '/seiscomp/EventParameters';
		my $evt_origID = findvalue("$root/event/preferredOriginID=",\@xml2);
		my @origin = findnode("$root/origin","/\@publicID=$evt_origID",\@xml2);
		my $evt_magID = findvalue("$root/event/preferredMagnitudeID=",\@xml2);
		my @magnitude = findnode('/magnitude',"/\@publicID=$evt_magID",\@origin);
		$qml{time} = findvalue('/time/value=',\@origin);
		$qml{rms} = findvalue('/quality/standardError=',\@origin);
		$qml{latitude} = findvalue('/latitude/value=',\@origin);
		$qml{latitudeError} = findvalue('/latitude/uncertainty=',\@origin);
		$qml{longitude} = findvalue('/longitude/value=',\@origin);
		$qml{longitudeError} = findvalue('/longitude/uncertainty=',\@origin);
		$qml{depth} = findvalue('/depth/value=',\@origin);
		$qml{depthError} = findvalue('/depth/uncertainty=',\@origin);
		$qml{gap} = findvalue('/quality/azimuthalGap=',\@origin);
		$qml{phases} = findvalue('/quality/usedPhaseCount=',\@origin);
		$qml{mode} = findvalue('/evaluationMode=',\@origin);
		$qml{status} = findvalue('/evaluationStatus=',\@origin);
		$qml{method} = findvalue('/methodID=',\@origin);
		$qml{model} = findvalue('/earthModelID=',\@origin);
		$qml{agency} = findvalue('/creationInfo/agencyID=',\@origin);
		$qml{magnitude} = findvalue('/magnitude/value=',\@magnitude);
		$qml{magtype} = findvalue('/type=',\@magnitude);
		$qml{type} = findvalue("$root/event/type=",\@xml2);
	}

	return %qml;
}

#--------------------------------------------------------------------------------------------------------------------------------------
# qmlvalues: returns origin and magnitude preferred values from XML2 arrayd
sub qmlfdsn {
	my $url = $_[0];
	my %qml;
	my @x;

	my @xml2 = qx(curl -s -S --globoff "$url" | $WEBOBS{XML2_PRGM});

	my $root = '/q:quakeml/eventParameters/event';
	my $evt_origID = findvalue("$root/preferredOriginID=",\@xml2);
	my @origin = findnode("$root/origin","/\@publicID=$evt_origID",\@xml2);
	my $evt_magID = findvalue("$root/preferredMagnitudeID=",\@xml2);
	my @magnitude = findnode("$root/magnitude","/\@publicID=$evt_magID",\@xml2);
	$qml{time} = findvalue('/time/value=',\@origin);
	$qml{rms} = findvalue('/quality/standardError=',\@origin);
	$qml{latitude} = findvalue('/latitude/value=',\@origin);
	$qml{latitudeError} = findvalue('/latitude/uncertainty=',\@origin);
	$qml{longitude} = findvalue('/longitude/value=',\@origin);
	$qml{longitudeError} = findvalue('/longitude/uncertainty=',\@origin);
	$qml{depth} = findvalue('/depth/value=',\@origin)/1000;
	$qml{depthError} = findvalue('/depth/uncertainty=',\@origin)/1000;
	$qml{gap} = findvalue('/quality/azimuthalGap=',\@origin);
	$qml{phases} = findvalue('/quality/usedPhaseCount=',\@origin);
	$qml{mode} = findvalue('/evaluationMode=',\@origin);
	$qml{status} = findvalue('/evaluationStatus=',\@origin);

	# for methodID and earthModelID takes only the last string to remove prefix
	#$qml{method} = findvalue('/methodID=',\@origin);
	@x = split(/\//,findvalue('/methodID=',\@origin));
	$qml{method} = $x[-1];
	#$qml{model} = findvalue('/earthModelID=',\@origin);
	@x = split(/\//,findvalue('/earthModelID=',\@origin));
	$qml{model} = $x[-1];

	$qml{agency} = findvalue('/creationInfo/agencyID=',\@origin);
	$qml{magnitude} = findvalue('/mag/value=',\@magnitude);
	$qml{magtype} = findvalue('/type=',\@magnitude);
	$qml{type} = findvalue("$root/type=",\@xml2);
	$qml{comment} = findvalue("$root/description/text=",\@xml2);

	return %qml;
}

1;
