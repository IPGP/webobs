function varargout = readhgt(varargin)
%READHGT Import/download NASA SRTM data files (.HGT).
%
%	X=READHGT(FILENAME) reads HGT "height" SRTM data file FILENAME
%	and returns a structure X containing following fields
%		lat: coordinate vector of latitudes (decimal degree)
%		lon: coordinate vector of longitudes (decimal degree)
%		  z: matrix of elevations (meters, INT16 class)
%
%	FILENAME must be in the form "[N|S]yy[E|W]xxx.hgt[.zip]" as downloaded
%	from SRTM data servers.
%
%	X=READHGT(LAT,LON) attemps to download the file *.hgt.zip corresponding 
%	to LAT and LON (in decimal degrees) coordinates (lower-left corner) 
%	from the USGS data server (needs an Internet connection and a companion  
%	file "readhgt_srtm_index.txt"). Downloaded filename(s) will be given in 
%	an additional output structure field X.hgt.
%
%	LAT and/or LON can be vectors: in that case, tiles corresponding to all
%	possible combinations of LAT and LON values will be downloaded, and
%	optional output structure X will have as much elements as tiles.
%
%	READGHT(...) without output argument or X=READHGT(...,'plot') plots the
%	tile(s). For better plot results, it is recommended to install DEM
%	personal function available at author's Matlab page. 
%
%	READHGT(LAT,LON,...,'merge'), in case of adjoining values of LAT and
%	LON, will concatenate tiles to produce a single one. ATTENTION: tiles
%	assembling may require huge computer ressources and cause disk swaping
%	or memory error.
%
%	READHGT(LAT,LON,...,'interp') linearly interpolates missing data.
%
%	READHGT(...,'crop',[LAT1,lAT2,LON1,LON2]) crops the map using
%	latitude/longitude limits. READHGT(LAT,LON,...,'crop'), without limits
%	argument vector, crops the resulting map around existing land (reduces 
%	any sea or novalue areas at the borders).
%	
%
%	READHGT(LAT,LON,...,'srtm3') forces SRTM3 download (by default, SRTM1
%	tile is downloaded if exists). Usefull for USA neighborhood.
%
%	READHGT(LAT,LON,OUTDIR) specifies output directory OUTDIR to write
%	downloaded files.
%
%	READHGT(LAT,LON,OUTDIR,URL) specifies the URL address to find HGT 
%	files (default is USGS).
%
%	Examples:
%	- to plot a map of the Paris region, France (single tile):
%		readhgt(48,2)
%
%	- to plot a map of Flores volcanic island, Indonesia (5 tiles):
%		readhgt(-9,119:123,'merge')
%
%	- to download SRTM1 data of Cascade Range (27 individual tiles):
%		X=readhgt(40:48,-123:-121);
%
%	Informations:
%	- each file corresponds to a tile of 1x1 degree of a square grid
%	  1201x1201 of elevation values (SRTM3 = 3 arc-seconds), and for USA  
%	  territory at higher resolution 3601x3601 grid (SRTM1 = 1 arc-second)
%	- elevations are of class INT16: sea level values are 0, unknown values
%	  equal -32768 (there is no NaN for INT class), use 'interp' option to
%	  fill the gaps
%	- note that borders are included in each tile, so to concatenate tiles
%	  you must remove one row/column in the corresponding direction (this
%	  is made automatically with the 'merge' option)
%	- downloaded file is written in the current directory or optional  
%	  OUTDIR directory, and it remains there
%	- NASA Shuttle Radar Topography Mission [February 11 to 22, 2000] 
%	  produced a near-global covering on Earth land, but still limited to 
%	  latitudes from 60S to 60N. Offshore tiles will be output as flat 0
%	  value grid
%	- if you look for other global topographic data, take a look to ASTER
%	  GDEM, worldwide 1 arc-second resolution (from 83S to 83N): 
%	  http://gdem.ersdac.jspacesystems.or.jp (free registration required)
%
%	Author: François Beauducel <beauducel@ipgp.fr>
%		Institut de Physique du Globe de Paris
%
%	References:
%		http://dds.cr.usgs.gov/srtm/version2_1
%
%	Acknowledgments: Yves Gaudemer
%
%	Created: 2012-04-22
%	Updated: 2013-01-17

%	Copyright (c) 2013, François Beauducel, covered by BSD License.
%	All rights reserved.
%
%	Redistribution and use in source and binary forms, with or without 
%	modification, are permitted provided that the following conditions are 
%	met:
%
%	   * Redistributions of source code must retain the above copyright 
%	     notice, this list of conditions and the following disclaimer.
%	   * Redistributions in binary form must reproduce the above copyright 
%	     notice, this list of conditions and the following disclaimer in 
%	     the documentation and/or other materials provided with the distribution
%	                           
%	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
%	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
%	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
%	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
%	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
%	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
%	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
%	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
%	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
%	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
%	POSSIBILITY OF SUCH DAMAGE.

url = 'http://dds.cr.usgs.gov/srtm/version2_1';
sz1 = [3601,3601]; % SRTM1 tile size (USA only)
sz3 = [1201,1201]; % SRTM3 tile size
novalue = intmin('int16'); % -32768
makeplot = 0;
merge = 0;
srtm3 = 0;
decimflag = 0;
decim = 0;
inter = 0;
cropflag = 0;
crop = [];

if nargin > 0 
	makeplot = any(strcmp(varargin,'plot'));
	merge = any(strcmp(varargin,'merge'));
	kcrop = find(strcmp(varargin,'crop'));
	if ~isempty(kcrop)
		cropflag = 1;
		if (kcrop + 1) <= nargin & isnumeric(varargin{kcrop+1})
			crop = varargin{kcrop+1};
			if any(size(crop) ~= [1,4])
				error('CROP option arguments must be a 1x4 vector.')
			end
			cropflag = 2;
			crop = [minmax(crop(1:2)),minmax(crop(3:4))];
		end
	end
	srtm3 = any(strcmp(varargin,'srtm3'));
	inter = any(strcmp(varargin,'interp'));
	kdecim = find(strcmp(varargin,'decim'));
	if ~isempty(kdecim)
		decimflag = 1;
		if (kdecim + 1) <= nargin & isnumeric(varargin{kdecim+1})
			decim = round(varargin{kdecim+1});
			if ~isscalar(decim) | decim < 1
				error('DECIM option argument must be a positive integer.')
			end
			decimflag = 2;
		end
	end
end
nargs = makeplot + merge + cropflag + srtm3 + inter + decimflag;

if nargin == 0
	[filename,pathname] = uigetfile('*.hgt;*.hgt.zip','Select a HGT file');
	f = {[pathname,filename]};
	if filename == 0
		error('Please select a HGT file or use function arguments.');
	end
end
if nargin == (1 + nargs)
	f = varargin{1};
	if ~ischar(f) | ~exist(f,'file')
		error('FILENAME must be a valid file name')
	end
	[pathname,filename,fileext] = fileparts(f);
	f = {f};
end
if nargin < (2 + nargs)
	lat = str2double(filename(2:3));
	if filename(1) == 'S'
		lat = -lat;
	end
	lon = str2double(filename(5:7));
	if filename(4) == 'W'
		lon = -lon;
	end
else
	lat = floor(varargin{1}(:));
	lon = floor(varargin{2}(:));
	if ~isnumeric(lon) | ~isnumeric(lat) | any(abs(lat) > 60) | any(lon < -180) | any(lat > 179) | isempty(lat) | isempty(lon)
		error('LAT and LON must be numeric and in valid SRTM interval (abs(LAT)<60).');
	end
	if merge & (any(diff(lat) ~= 1) | any(diff(lon) ~= 1))
		error('With MERGE option, LAT and LON must be adjoining tiles.');
	end

	% if LAT/LON are vectors, NDGRID makes a grid of corresponding tiles
	[lat,lon] = ndgrid(lat,lon);
	f = cell(size(lat));
	for n = 1:numel(f)
		if lat(n) < 0
			slat = sprintf('S%02d',-lat(n));
		else
			slat = sprintf('N%02d',lat(n));
		end
		if lon(n) < 0
			slon = sprintf('W%03d',-lon(n));
		else
			slon = sprintf('E%03d',lon(n));
		end
		ff = sprintf('%s%s.hgt.zip',slat,slon);
		out = '.';
		f{n} = sprintf('%s/%s%s.hgt',out,slat,slon);

		if ~exist(f{n},'file') | srtm3
			if nargin > (2 + nargs)
				out = varargin{3};
				if ~exist(out,'dir')
					error('OUTDIR must be a valid directory.')
				end
			end
			if nargin > (3 + nargs)
				url = varargin{4};
				if ~ischar(url)
					error('URL must be a string.');
				end
			else
				fidx = 'readhgt_srtm_index.txt';
				% ATTENTION: this file must exist in the Matlab path
				% since USGS delivers data continent-by-continent with nominative directories,
				% this index file is needed to know the full path name of each tile.
				if exist(fidx,'file')
					fid = fopen(fidx,'rt');
					idx = textscan(fid,'%s');
					fclose(fid);
					k = find(~cellfun('isempty',strfind(idx{1},ff)));
					if isempty(k)
						fprintf('READHGT: Warning! Cannot find %s tile in SRTM database. Consider it offshore...\n',ff);
						ff = '';
					else
						% forces SRTM3 option: takes the first match in the list
						if srtm3
							ff = idx{1}{k(1)};
						else
							ff = idx{1}{k(end)};
						end
					end
				else
					error('Cannot find "%s" index file to parse SRTM database. Please download HGT file manually.',ff);
				end
			end
			if isempty(ff)
				f{n} = '';
			else
				f(n) = unzip([url,ff],out);
				fprintf('File "%s" downloaded from %s%s\n',f{n},url,ff)
			end
		end
	end
end

% pre-allocates X structure (for each file/tile)
X = repmat(struct('hgt',[],'lat',[],'lon',[]),[n,1]);

if n == 1
	merge = 1;
end

for n = 1:numel(f)
	% unzips HGT file if needed
	if ~isempty(strfind(f{n},'.zip'));
		X(n).hgt = char(unzip(f{n}));
		funzip = 1;
	else
		X(n).hgt = f{n};
		funzip = 0;
	end

	sz = sz3;
	if isempty(f{n})
		% offshore: makes a tile of zeros...
		X(n).z = zeros(sz);
	else
		% loads data from HGT file
		fid = fopen(X(n).hgt,'rb','ieee-be');
			X(n).z = fread(fid,'*int16');
		fclose(fid);
		switch numel(X(n).z)
		case prod(sz1)
			sz = sz1;
		case prod(sz3)
			sz = sz3;
		otherwise
			error('"%s" seems not a regular SRTM data file or is corrupted.',X(n).hgt);
		end
		X(n).z = rot90(reshape(X(n).z,sz));

		% erases unzipped file if necessary
		if (funzip)
			delete(f{n});
		end
	end

	% builds latitude and longitude coordinates
	X(n).lon = linspace(lon(n),lon(n)+1,sz(2));
	X(n).lat = linspace(lat(n),lat(n)+1,sz(1))';
	
	% interpolates NaN (if not merged)
	if inter & ~merge
		X(n).z = fillgap(X(n).lon,X(n).lat,X(n).z,novalue);
	end
end

if merge
	% NOTE: cannot merge mixted SRTM1 / SRTM3 or discontiguous tiles
	Y.lat = linspace(min(lat(:)),max(lat(:))+1,size(lat,1)*(sz(1)-1)+1)';
	Y.lon = linspace(min(lon(:)),max(lon(:))+1,size(lon,2)*(sz(2)-1)+1);
	Y.z = zeros(length(Y.lat),length(Y.lon),'int16');
	for n = 1:numel(X)
		Y.z((sz(1)-1)*(X(n).lat(1)-Y.lat(1)) + (1:sz(1)),(sz(2)-1)*(X(n).lon(1)-Y.lon(1)) + (1:sz(2))) = X(n).z;
	end

	if cropflag
		if cropflag == 1 | isempty(crop)
			klat = firstlast(any(Y.z ~= 0 & Y.z ~= novalue,2));
			klon = firstlast(any(Y.z ~= 0 & Y.z ~= novalue,1));
		else
			klat = find(Y.lat >= crop(1) & Y.lat <= crop(2));
			klon = find(Y.lon >= crop(3) & Y.lon <= crop(4));
		end			
		Y.lat = Y.lat(klat);
		Y.lon = Y.lon(klon);
		Y.z = Y.z(klat,klon);
	end
	
	if inter
		Y.z = fillgap(Y.lon,Y.lat,Y.z,novalue);
	end
end

if nargout == 0 | makeplot
	if merge
		fplot(Y.lon,Y.lat,Y.z,decim,url,novalue)
	else
		for n = 1:numel(X)
			fplot(X(n).lon,X(n).lat,X(n).z,decim,url,novalue)
		end
	end
end

if nargout == 3 % for backward compatibility...
	varargout{1} = X(1).lon;
	varargout{2} = X(1).lat;
	varargout{3} = X(1).z;
elseif nargout > 0
	if merge
		varargout{1} = Y;
	else
		varargout{1} = X;
	end
	if nargout == 2
		varargout{2} = f{1}; % for backward compatibility...
	end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function fplot(x,y,z,decim,url,novalue)
%FPLOT plot the data using DEM function if exists, or IMAGESC

demoptions = {'dms','scale','lake','nodecim'};

figure
if decim
	n = decim;
else
	n = ceil(sqrt(numel(z))/1201);
end
if n > 1
	x = x(1:n:end);
	y = y(1:n:end);
	z = z(1:n:end,1:n:end);
	fprintf('READHGT: In the figure data has been decimated by a factor of %d...\n',n);
end

if exist('dem','file')
	dem(x,y,z,demoptions{:})
else
	warning('For better results you might install the function dem.m from http://www.ipgp.fr/~beaudu/matlab.html#DEM')
	z(z==novalue) = 0;
	imagesc(x,y,z);
	if exist('landcolor','file')
		colormap(landcolor(256).^1.3)
	else
		colormap(jet)
	end
	% aspect ratio (lat/lon) is adjusted with mean latitude
	xyr = cos(mean(y)*pi/180);
	set(gca,'DataAspectRatio',[1,xyr,1])

	orient tall
	axis xy, axis tight
end

title(sprintf('Data SRTM/NASA from %s',url),'FontSize',12,'Interpreter','none')



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y = firstlast(x)

k = find(x);
y = k(1):k(end);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y = minmax(x)

y = [min(x(:)),max(x(:))];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function z = fillgap(x,y,z,novalue)
% GRIDDATA is not efficient for large arrays, but has great advantage to be
% included in Matlab core functions! To optimize interpolation, we
% reduce the number of relevant data by building a mask of surrounding
% pixels of novalue areas... playing with linear index!

sz = size(z);
k = find(z == novalue);
k(k == 1 | k == numel(z)) = []; % removes first and last index (if exist)
if ~isempty(k)
	[xx,yy] = meshgrid(x,y);
	mask = zeros(sz,'int8');
	k2 = ind90(sz,k); % k2 is linear index in the row order
	% sets to 1 every previous and next index, both in column and row order
	mask([k-1;k+1;ind90(fliplr(sz),[k2-1;k2+1])]) = 1; 
	mask(k) = 0; % removes the novalue index
	kb = find(mask); % keeps only border values
	z(k) = int16(griddata(xx(kb),yy(kb),double(z(kb)),xx(k),yy(k)));
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function k2 = ind90(sz,k)

[i,j] = ind2sub(sz,k);
k2 = sub2ind(fliplr(sz),j,i); % switched i and j: k2 is linear index in row order
