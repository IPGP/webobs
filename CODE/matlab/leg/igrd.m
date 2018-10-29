function [x,y,z] = igrd(fn)
%IGRD	Import DEM in .GRD formats (Surfer, ArcInfo / GMT).
%	[X,Y,Z] = IGRD(FILENAME) returns the Digital Elevation Model data 
%	defined by X and Y (vectors or matrix) and matrix Z of elevations.
%	FILENAME is in one the data grid .GRD formats: Golden Sofware Surfer (ASCII
%	or binary), Arc/Info (ASCII), or Generic Mapping Tool (ASCII only).
%
%	NoData values are replaced by NaN.
%
%	Author: François Beauducel, IPG Paris.
%	Created: 1996
%	Updated: 2013-01-06
%
%	References:
%	   Golden Software Surfer, http://www.goldensoftware.com/
%	   GMT (Generic Mapping Tools), http://gmt.soest.hawaii.edu

%	Copyright (c) 1996-2013, François Beauducel, covered by BSD License.
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

% lauch Open File dialog box if no file is specified
if nargin < 1
	[f,p] = uigetfile('*.grd','Select the GRD file');
	fn = [p,f];
end

ndv = -99999;                % default NoValue

if ~exist(fn,'file')
	error('File "%s" not found.',fn);
end

fid = fopen(fn, 'r');
l = fgets(fid);             % reads 1st line header

% case of Golden Software/Surfer grid ASCII file
if strfind(l,'DSAA')
	sz = fscanf(fid, '%d', [1 2]);
	xm = fscanf(fid, '%f', 2);
	ym = fscanf(fid, '%f', 2);
	zm = fscanf(fid, '%f', 2);
	z = fscanf(fid, '%f', sz)';

% case of Golden Software/Surfer grid BINARY file
elseif strfind(l,'DSBB')
	fclose(fid);
	fid = fopen(fn,'rb');
	co = fscanf(fid,'%c',4);
	sz = fread(fid,2,'int16')';
	xm = fread(fid,2,'float64')';
	ym = fread(fid,2,'float64')';
	zm = fread(fid,2,'float64')';
	z = reshape(fread(fid,'float32'),sz)';

% case of ESRI/ArcInfo grid ASCII file (added in 2009)
elseif strfind(l,'ncols')
	s = textscan(l,'%s');
	
	if strcmpi(s{1}(1),'ncols')
		x = 1;
		v = 2;
		cf = '%s%n';
	else
		x = 2;
		v = 1;
		cf = '%n%s';
	end
	sz(1) = str2double(s{1}{v});

	for i = 1:5
		l = fgets(fid);
		s = textscan(l,cf);
		switch lower(s{x}{:})
		case 'nrows'
			sz(2) = s{v};
		case {'xllcorner','xllcenter','xll'}
			xm(1) = s{v};
		case {'yllcorner','yllcenter','yll'}
			ym(1) = s{v};
		case 'cellsize'
			cs = s{v};
		case 'nodata_value'
			ndv = s{v};
		otherwise
			warning('"%s" (=%g) header unknown.\n',s{x}{:},s{v})
		end
	end
	xm(2) = xm(1) + (sz(1)-1)*cs;
	ym(2) = ym(1) + (sz(2)-1)*cs;	% note the reverse order of Y-axis vector
	z = flipud(fscanf(fid, '%f', sz)');	% transform needed because Z values are sorted rowwise
    
elseif strfind(l,'CDF')
	error('"%s" is a binary netCDF grid file. Cannot be read, yet...\nConvert it first using "grd2xyz -Ef" command.',fn)
else
	error('"%s" is not a valid GRD file for this function.',fn)
end

fclose(fid);

x = linspace(xm(1),xm(2),sz(1));
y = linspace(ym(1),ym(2),sz(2))';

% replace NoData values by NaN
z(z == ndv | z > 1e38) = NaN;

