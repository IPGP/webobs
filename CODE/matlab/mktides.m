function T = mktides(prgm,opt,t,lat,lon,alt,ptmp)
%MKTIDES Computes theoretical tides
%	T=MKTIDES(PRGM,OPT,T,LAT,LON,ALT) computes the theoretical tides using
%	the 'gotic2' program (executable in string PRGM), options OPT, time
%	span T, for a geographical location defined by LAT, LON (decimal degree)
%	and elevation ALT (meter). Options are defined by a cell vector
%	OPT = {TIDEMODE,WAVE,KIND}:
%	   TIDEMODE = 1 (solid Earth + ocean loading)
%	            = 2 (solid Earth tide)
%	            = 3 (ocean loading tide)
%	   WAVE = 'ALL' (all waves, default)
%	   KIND = 'TL' (Tilt, default)
%	          'RD' (Radial displacement)
%	          'HD' (Horizontal displacement)
%	          'GV' (Gravity)
%	          'ST' (Strain)
%	          'DV' (Deflection of the vertical)
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2015
%	Updated: 2024-08-26


g = 9.81;


if isscalar(opt)
	tidemode = opt;
	wavemode = 'ALL';
	kindmode = 'TL';
else
	tidemode = opt{1};
	wavemode = opt{2};
	if numel(opt) > 2
		kindmode = opt{3};
	end
end

if nargin < 7
	ptmp = sprintf('/tmp/mktides/%s',randname(16));
	delflag = 1;
else
	delflag = 0;
end

finp = sprintf('%s/tides.inp',ptmp);
ftmp = sprintf('%s/tides.tmp',ptmp);
fdat = sprintf('%s/tides.dat',ptmp);

tt1 = datestr(min(t),'yyyymmddHHMM');
tt2 = datestr(max(t),'yyyymmddHHMM');
fprintf('WEBOBS{mktides}: calcutates theoretical tides at %gN,%gE from %s to %s... ',lat,lon,tt1,tt2);

wosystem(sprintf('mkdir -p %s',ptmp));
fid = fopen(finp,'wt');
fprintf(fid,'*********************[ Mandatory Cards ]**********************\n');
fprintf(fid,'STAPOSD WEBOBS, %g, %g, %g, 0\n',lon,lat,alt);
fprintf(fid,'WAVE    %s\n',wavemode);
fprintf(fid,'KIND    %s\n',kindmode);
fprintf(fid,'**********************[ Option Cards ]************************\n');
fprintf(fid,'PREDICT %d, %s, %s, 1.0\n',tidemode,tt1,tt2);
fprintf(fid,'PREFMT  5, 2\n');
fprintf(fid,'PREOUT  %s\n',fdat);
fprintf(fid,'END\n');
fclose(fid);
setenv('DYLD_LIBRARY_PATH', '/usr/local/bin/');
setenv('LD_LIBRARY_PATH', '');
wosystem(sprintf('cd $(dirname %s);%s < %s > /dev/null',prgm,prgm,finp'));

if exist(fdat,'file')
	wosystem(sprintf('sed "s/[:\\/]/ /g" %s > %s',fdat,ftmp));
	dd = load(ftmp);
	T.t = datenum(dd(:,1),dd(:,2),dd(:,3),dd(:,4),dd(:,5),0);
	switch kindmode
		case 'TL'
			T.d = g*dd(:,[7,6]);
		otherwise
			T.d = dd(:,6);
	end
	fprintf('done.\n');
else
	fprintf('** WARNING ** tides file does not exist!\n');
end

if delflag
	wosystem(sprintf('rm -rf %s',ptmp));
end
