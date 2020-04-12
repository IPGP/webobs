function X=readcities(WO,P,varargin)
%READCITIES Read cities file
%	READCITIES(WO,F) reads the cities file F and returns a 1-D structure with
%	fields:
%	    lat: city latitude
%	    lon: city longitude
%	   name: city name
%	 region: city region
%	 factor: site amplification factor
%
%	READCITIES(WO,P) uses parameters from PROC's structure P (P.CITIES field must
%	be set).
%
%	READCITIES(...,'elevation') will use ETOPO or SRTM topographic data to get
%	the elevation for each city of P.REGION if defined, and add another field to
%	the output structure:
%	    alt: city elevation (in m)
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2016-10-16, in Yogyakarta, Indonesia
%	Updated: 2020-04-12


if isstruct(P)
	f = field2str(P,'CITIES');
	region = field2str(P,'REGION');
else
	f = P;
	region = '';
end

if ~exist(f,'file')
	error('File "%s" does not exist. Check input argument or define CITIES parameter in the PROC.',f)
end

fprintf('WEBOBS{readcities}: reading "%s" ... ',f);

% loads cities parameters: latitude,longitude,name,region,amplification
fid = fopen(f);
	c = textscan(fid,'%n%n%q%q%n','Delimiter','|','CommentStyle','#');
fclose(fid);

fprintf('done (%d cities).\n',length(c{1}));

X.lat = c{1};
X.lon = c{2};
X.name = c{3};
X.region = c{4};
X.factor = c{5};
X.factor(isnan(X.factor)) = 1;

if any(strcmpi(varargin,'elevation'))
	X.alt = zeros(size(X.lat));
	% gets the cities elevations for region (topography interpolation)
	k = strcmpi(X.region,region);
	DEM = loaddem(WO,[minmax(X.lon(k)),minmax(X.lat(k))]);
	X.alt(k) = interp2(DEM.lon,DEM.lat,double(DEM.z),X.lon(k),X.lat(k));
	X.alt(isnan(X.alt)) = 0;
end
