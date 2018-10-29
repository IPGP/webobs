% test webobs procs

runs = { ...
	'genplot GEOSCOPE','superproc genplot + format seedlink';
	'genplot MULTIGAS all','superproc genplot + format ascii';
	'tilt MERAPITILT 01y','superproc tilt + format sql-table';
	'hypomap HYPOREU 01y','superproc hypomap + format scevtlog-xml';
	'hypomap USGS 01y','superproc hypomap + format fdsnws-event';
	'gnss GPSDOMERAPIGIPSY all','superproc gnss + format gipsy';
	'meteo METEOMAR all','superproc meteo + format T0A5';
	'afm RIVIERE all','superproc afm + format porky-asc';
	'waters SOURCES 50y','superproc waters + format wodbform EAUX';
	'extenso EXTENSO 10y','superproc extenso + format wodbform EXTENSO';
	'gridmaps({''PROC.EXTENSO'',''PROC.GEOSCOPE''})','gridmaps with user-DEM + SRTM + ETOPO + multiple maps';
	'locastat PSAMEA01','locastat 1 node';
	'sefran3','sefran3 GEOSCOPE';
	};

for r = 1:size(runs,1)
	if isempty(input(sprintf('\n\n** Run "%s" - %s (Y)?',runs{r,1},runs{r,2}),'s'))
		eval(runs{r,1});
	end
end
