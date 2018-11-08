function [a,b,c,d] = besself(n,w,varargin)
% Copyright (C) 1999 Paul Kienzle <pkienzle@users.sf.net>
% Copyright (C) 2003 Doug Stewart <dastew@sympatico.ca>
% Copyright (C) 2009 Thomas Sailer <t.sailer@alumni.ethz.ch >
% Copyrigth (C) 2018 Francois Beauducel <beauducel@ipgp.fr>

%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; see the file COPYING. If not, see
% <https://www.gnu.org/licenses/>.

% -*- texinfo -*-
% @deftypefn  {Function File} {[@var{b}, @var{a}] =} besself (@var{n}, @var{w})
% @deftypefnx {Function File} {[@var{b}, @var{a}] =} besself (@var{n}, @var{w}, 'high')
% @deftypefnx {Function File} {[@var{z}, @var{p}, @var{g}] =} besself (@dots{})
% @deftypefnx {Function File} {[@var{a}, @var{b}, @var{c}, @var{d}] =} besself (@dots{})
% @deftypefnx {Function File} {[@dots{}] =} besself (@dots{}, 'z')
% Generate a Bessel filter.
% Default is a Laplace space (s) filter.
%
% [b,a] = besself(n, Wc)
%    low pass filter with cutoff pi*Wc radians
%
% [b,a] = besself(n, Wc, 'high')
%    high pass filter with cutoff pi*Wc radians
%
% [z,p,g] = besself(...)
%    return filter as zero-pole-gain rather than coefficients of the
%    numerator and denominator polynomials.
%
% [...] = besself(...,'z')
%     return a discrete space (Z) filter, W must be less than 1.
%
% [a,b,c,d] = besself(...)
%  return  state-space matrices
%
% References:
%
% Proakis & Manolakis (1992). Digital Signal Processing. New York:
% Macmillan Publishing Company.
% @end deftypefn


if (nargin > 4 || nargin < 2 || nargout > 4 || nargout < 2)
	error('Number of input arguments is not correct.');
end

% interpret the input parameters
if ~(isscalar (n) && (n == fix (n)) && (n > 0))
	error ('besself: filter order N must be a positive integer');
end

stop = false;
digital = false;
for i = 1:numel(varargin)
	switch varargin{i}
	case 's'
		digital = false;
	case 'z'
		digital = true;
	case {'high', 'stop'}
		stop = true;
	case {'low', 'pass'}
		stop = false;
	otherwise
		error('besself: expected [high|stop] or [s|z]');
	end
end

% FIXME: Band-pass and stop-band currently non-functional, remove
%        this check once low-pass to band-pass transform is implemented.
if ~isscalar(w)
	error('besself: band-pass and stop-band filters not yet implemented');
end

if ~((numel (w) <= 2) && (size(w,2) == 1 || size(w,1) == 1))
	error('besself: frequency must be given as WC or [WL, WH]');
elseif (numel (w) == 2) && (w(2) <= w(1))
	error('besself: W(1) must be less than W(2)');
end

if digital && ~all ((w >= 0) & (w <= 1))
	error('besself: all elements of W must be in the range [0,1]');
elseif (~ digital && ~ all (w >= 0))
	error('besself: all elements of W must be in the range [0,inf]');
end

% Prewarp to the band edges to s plane
if (digital)
	T = 2;       % sampling frequency of 2 Hz
	w = 2 / T * tan(pi * w / T);
end

% Generate splane poles for the prototype Bessel filter
[zero, pole, gain] = besselap(n);

% splane frequency transform
[zero, pole, gain] = sftrans(zero, pole, gain, w, stop);

% Use bilinear transform to convert poles to the z plane
if (digital)
	[zero, pole, gain] = bilinear(zero, pole, gain, T);
end

% convert to the correct output form
if (nargout == 2)
	a = real (gain * poly(zero));
	b = real (poly(pole));
elseif (nargout == 3)
	a = zero;
	b = pole;
	c = gain;
else
	% output ss results
	[a,b,c,d] = zp2ss(zero, pole, gain);
end

