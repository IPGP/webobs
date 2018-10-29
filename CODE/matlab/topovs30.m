function varargout = topovs30(x,y,z,pga,varargin)
%TOPOVS30 Topographic slope Vs30 site amplification.
%	X=TOPOVS30(X,Y,Z,PGA) computes the site amplification
%	factors from topography X and Y coordinate vectors (in meters),
%	elevation matrix Z (in meters), and peak ground accelerations matrix 
%	PGA (in cm/s/s) and returns a structure X with following fields:
%		    f: short-period acceleration factor
%		 Vs30: Vs30 velocity (in m/s)
%	    NEHRP: class letter (cell of strings)
%
%	Each of these fields has the same matrix size as PGA and Z.
%
%	TOPOVS30(X,Y,Z,PGV,'pgv') computes the mid-period velocity 
%	amplification factors from peak ground velocities PGV (in m/s).
%
%	TOPOVS30(...,'latlon') considers X as longitude and Y as latitude
%	coordinates (in degrees). This allows correct slope computation.
%
%	TOPOVS30(...,'active') or TOPOVS30(...,'stable') forces the tectonic
%	regime instead of automatic detection from mean slope range.
%
%	TOPOVS30(...) with no output argument or []=TOPOVS30(...'plot') plots
%	the map of F factor.
%
%	Author: François Beauducel <beauducel@ipgp.fr>
%		Institut de Physique du Globe de Paris
%
%	Acknowledgments: Jean-Marie Saurel
%
%	Reference:
%		Wald D.J. and T.I. Allen (2007), Topographic Slope as a Proxy for 
%		Seismic Site Conditions and Amplification, Bull. Seismol. Soc. Am.,
%		97:5, 1379-?1395, doi:10.1785/0120060267
%
%	Created: 2016-02-06 in Yogyakarta, Indonesia
%	Updated: 2016-02-08

%	Copyright (c) 2016, François Beauducel, covered by BSD License.
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

if nargin < 4
	error('Not enough input arguments.')
end

degkm = 6378*pi/180; % one latitude degree in km

NEHRP = {'E','D','C','B'};
VS30 = [163 301 464 686];	% Vs30 velocity (in m/s)

XPGA = [100 200 300 400];		% PGA range (in cm/s/s)
FPGA = [ ...
	1.65 1.43 1.15 0.93;	% class E
	1.33 1.23 1.09 0.96;	% class D
	1.15 1.10 1.04 0.98;	% class C
	1.00 1.00 1.00 1.00;	% class B
];

% input options
pgv = any(strcmpi(varargin,'pgv'));
latlon = any(strcmpi(varargin,'latlon'));
active = any(strcmpi(varargin,'active'));
stable = any(strcmpi(varargin,'stable'));
nozero = any(strcmpi(varargin,'nozero'));
plot = any(strcmpi(varargin,'plot'));
debug = any(strcmpi(varargin,'debug'));

if latlon
	ry = degkm*1000;
	rx = degkm*1000*cosd(mean(y));
else
	rx = 1;
	ry = 1;
end

[fx,fy] = gradient(z,x*rx,y*ry);
slope = max(abs(fx),abs(fy));

% automatic detection of tectonic range
if ~active && ~stable
	slopemean = mean(slope(:));
	if slopemean > 0.05
		active = true;
	end
	if debug
		fprintf('Mean slope = %g m/m : ',slopemean);
		if active
			fprintf('Active tectonic\n');
		else
			fprintf('Stable continent\n');
		end
	end
end

% defines the slope range (lower limit) for class E,D,C,B
if active
	nehrp = [0,1e-4,0.018,0.138,Inf];
else
	nehrp = [0,2e-5,7.2e-3,0.025,Inf];
end

% interpolates the NEHRP class and the amplification factor
c = nan(size(slope));
f = ones(size(slope));
for n = 1:length(nehrp)-1
	k = find(slope >= nehrp(n) & slope < nehrp(n+1));
	c(k) = n;
	f(k) = interp1(XPGA,FPGA(n,:),pga(k),'nearest','extrap');
end

% nozero option: forces 1 at zero level (for example sea level)
if nozero
	f(z == 0) = 1;
end

if nargout == 0 || plot
	figure
	imagesc(x,y,f)
	axis xy
	colorbar
end

if nargout > 0
	X.f = f;
	if debug
		X.c = c;
	end
	X.Vs30 = VS30(c);
	X.NEHRP = NEHRP(c);
	varargout{1} = X;
end

