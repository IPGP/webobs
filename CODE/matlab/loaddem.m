function DEM = loaddem(WO,xylim,OPT)
%LOADDEM Load Digital Elevation Model
%	DEM = LOADDEM(WO,XYLIM) loads digital elevation model for a rectangular
%	area defined by XYLIM = [LON1,LON2,LAT1,LAT2], and returns a structure
%	DEM with fields:
%	         lat: latitude vector (in decimal degree)
%	         lon: longitude vector (in decimal degree)
%	           z: elevation matrix (in m)
%	   COPYRIGHT: copyright string
%
%	LOADDEM will use SRTM data if WO.SRTM_MAX_TILES maximum number
%	of tiles is not reached, and ETOPO data instead for larger areas (see
%	corresponding WO.*ETOPO* variables).
%
%	LOADDEM(WO,XYLIM,OPT) uses optional fields from structure OPT:
%	       DEM_SRTM1: forces SRTM1 (30m)
%	        DEM_FILE: user's DEM filename (ArcInfo format)
%	        DEM_TYPE: 'UTM' or 'LATLON'
%	   DEM_COPYRIGHT: user's copyright string
%	      DEM_FORCED: Y or YES to force the use of user's DEM even if it
%	                  doesn't cover the entire requested area
%	ETOPO_SRTM_MERGE: Y to force ETOPO+SRTM merge, overwrites WEBOBS.rc
%
%	If OPT.DEM_FILE does not exist or user's DEM does not cover the entire 
%	requested area XYLIM, then SRTM/ETOPO data are returned instead.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2014-07-16
%	Updated: 2019-07-08


wofun = sprintf('WEBOBS{%s}',mfilename);

dlon = xylim(1:2);
dlat = xylim(3:4);

srtmmax = field2num(WO,'SRTM_MAX_TILES',25);
psrtm1 = field2str(WO,'PATH_DATA_DEM_SRTM1');
srtm1max = field2num(WO,'SRTM1_MAX_TILES',4);
oversamp = field2num(WO,'DEM_OVERSAMPLING',500);
maxwidth = field2num(WO,'DEM_MAX_WIDTH',1201);
mergeetopo = isok(WO,'ETOPO_SRTM_MERGE',1);
srtm1 = false;
etopo = false;
if nargin > 2
	srtm1 = isok(OPT,'DEM_SRTM1');
	srtmmax = field2num(OPT,'SRTM_MAX_TILES',srtmmax);
	srtm1max = field2num(OPT,'SRTM1_MAX_TILES',srtm1max);
	mergeetopo = isok(OPT,'ETOPO_SRTM_MERGE',mergeetopo);
end

% makes SRTM directories
wosystem(sprintf('mkdir -p %s',WO.PATH_DATA_DEM_SRTM));
if srtm1 && ~isempty(psrtm1)
	wosystem(sprintf('mkdir -p %s',psrtm1));
end
setenv('LD_LIBRARY_PATH', '');

% if user-defined DEM exists (and contains some valid data for the requested map)
userdem = 0;
if nargin > 2 && isfield(OPT,'DEM_FILE')
	f = OPT.DEM_FILE;
	fprintf('%s: loading user DEM file "%s"... ',wofun,f);
	if exist(f,'file')
		[x,y,z] = igrd(f);
		fprintf('done.\n');
		forced = isok(OPT,'DEM_FORCED');
		if isfield(OPT,'DEM_TYPE') && strcmp(OPT.DEM_TYPE,'UTM')
			fprintf('%s: converting user''s DEM from UTM to lat/lon... ',wofun);
			[dx,dy,zone] = ll2utm(repmat(dlat,2,1),repmat(dlon,2,1));
			epsxy = 2*max(abs(diff(x(1:2))),abs(diff(y(1:2))));
			kx = find(x >= min(dx(:,1) - epsxy) & x <= max(dx(:,2) + epsxy));
			ky = find(y >= min(dy(:,1) - epsxy) & y <= max(dy(:,2) + epsxy));
			[x,y,z] = gridutm2ll(x(kx),y(ky),z(ky,kx),zone);
			fprintf('done.\n');
		end
		if forced || (all(isinto(dlon,x)) && all(isinto(dlat,y)))
			DEM.lon = x(x >= dlon(1) & x <= dlon(2)); 
			DEM.lat = y(y >= dlat(1) & y <= dlat(2)); 
			DEM.z = z(y >= dlat(1) & y <= dlat(2),x >= dlon(1) & x <= dlon(2)); 
			DEM.COPYRIGHT = field2str(OPT,'DEM_COPYRIGHT','User''s defined DEM');
			if ~isempty(DEM.z)
				userdem = 1;
			end
		else
			fprintf('%s: ** WARNING ** user DEM does not match the entire area map; uses global data...\n',wofun);
		end
	else
		fprintf('\n%s: ** WARNING ** file does not exist!\n',wofun);
	end
end

if ~userdem 
	% if max SRTM tiles exceeded, loads ETOPO
	n = (abs(diff(floor(dlon))) + 1)*(abs(diff(floor(dlat))) + 1);
	if n > srtmmax || min(dlat) < -60 || max(dlat) > 59
		fprintf('%s: loading ETOPO data for area lat (%g,%g) lon (%g,%g)...\n',wofun,dlat,dlon);
		DEM = ibil(sprintf('%s/%s',WO.PATH_DATA_DEM_ETOPO,WO.ETOPO_NAME),xylim);
		DEM.z = double(DEM.z);
		DEM.COPYRIGHT = field2str(WO,'ETOPO_COPYRIGHT','DEM: ETOPO/NOOA');
		etopo = true;
	else
		fprintf('%s: loading SRTM data for area lat (%g,%g) lon (%g,%g)...\n',wofun,dlat,dlon);
		if srtm1 && exist(psrtm1,'dir') && n <= srtm1max
			DEM = readhgt([dlat,dlon],'outdir',psrtm1,'interp','srtm1','wget');
		else
			DEM = readhgt([dlat,dlon],'outdir',WO.PATH_DATA_DEM_SRTM,'interp','srtm3','wget');
		end
		DEM.z = double(DEM.z);
		DEM.z(DEM.z==-32768) = NaN;
		DEM.COPYRIGHT = field2str(WO,'SRTM_COPYRIGHT','DEM: SRTM/NASA');
	end

	% limits the size of DEMs to avoir memory problems
	n = ceil(sqrt(numel(DEM.z))/maxwidth);
	if n > 1
		DEM.lat = DEM.lat(1:n:end);
		DEM.lon = DEM.lon(1:n:end);
		DEM.z = DEM.z(1:n:end,1:n:end);
	end

	% adds bathymetry from ETOPO for SRTM offshore areas
	if mergeetopo && ~userdem && ~etopo
		k = find(DEM.z==0);
		if ~isempty(k)
			% loads ETOPO1 with +/- 2 minutes of extra borders
			E = ibil(sprintf('%s/%s',WO.PATH_DATA_DEM_ETOPO,WO.ETOPO_NAME),xylim + 5/60*[-1,1,-1,1]);
			[xx,yy] = meshgrid(DEM.lon,DEM.lat);
			DEM.z(k) = min(floor(interp2(E.lon,E.lat,E.z,xx(k),yy(k),'*linear')),0);
			DEM.COPYRIGHT = sprintf('%s + ETOPO/NOOA',DEM.COPYRIGHT);
		end
	end

end

% if too low resolution, oversamples...
if max(size(DEM.z)) < oversamp
	%[xi,yi] = meshgrid(linspace(DEM.lon(1),DEM.lon(end),oversamp),linspace(DEM.lat(1),DEM.lat(end),oversamp));
	[xi,yi] = meshgrid(linspace(dlon(1),dlon(2),oversamp),linspace(dlat(1),dlat(2),oversamp));
	if any(size(DEM.z)<2)
		method = '*nearest';
	else
		method = '*linear';
	end
	DEM.z = interp2(DEM.lon,DEM.lat,DEM.z,xi,yi,method);
	DEM.lon = xi(1,:);
	DEM.lat = yi(:,1);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [xi,yi,zi] = gridutm2ll(x,y,z,zone)
%UTM to latitude/longitude conversion of DEM
%	[LON,LAT,Z] = GRIDUTM2LL(E,N,Z,ZONE)


% number of pixel of final Lat/Lon DEM
nn = 1000;

% converts x/y vectors in coordinates matrix
[xx,yy] = meshgrid(x,y);

% main UTM2LL conversion
ll = utm2ll(xx(:),yy(:),zone);

% rebuilts coordinate matrix
lat = reshape(ll(:,1),size(z));
lon = reshape(ll(:,2),size(z));

z(z==0) = -1;

% LAT/LON border limits are not rectangular after conversion from UTM: takes inner borders
xi = linspace(max(lon(:,1)),min(lon(:,end)),nn);
yi = linspace(max(lat(1,:)),min(lat(end,1)),nn);
[xx,yy] = meshgrid(xi,yi);

% interpolation on a regular grid
zi = griddata(lon(:),lat(:),z(:),xx,yy,'linear');

