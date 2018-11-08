function [a,b,c,d] = cheby2(n,rs,w,varargin)
%CHEBY2 Chebyshev Type I filter design.
%	[B,A] = CHEBY2(N,RS,WP) returns the transfer function coefficients of an
%	Nth-order lowpass digital Chebyshev Type II filter with normalized 
%	passband edge frequency WP and RS decibels of stopband attenuation down
%	from the peak passband value.
%
%	[B,A] = CHEBY2(N,RP,WP,FTYPE) designs a lowpass, highpass, bandpass, or
%	bandstop filter, depending on the value of FTYPE and the number of 
%	elements of WP. The resulting bandpass and bandstop designs are of order
%	2N. FTYPE can be:
%		'low' is lowpass, default if WP is scalar,
%		'high' is highpass, WP must be scalar,
%		'bandpass' is bandpass, default if WP is a two-element vector,
%		'stop' is bandstop, WP must be a two-element vector.
%
%	[Z,P,K] = CHEBY2(...) returns its zeros, poles, and gain.
%
%	[A,B,C,D] = CHEBY2(...) returns the matrices that specify its state-space
%	representation.
%
%	[...] = CHEBY2(...,'s') designs a lowpass, highpass, bandpass, or bandstop
%	analog Chebyshev Type II filter with stopband edge angular frequency WP and 
%	RS decibels of stopband attenuation.
%
%
%	References:
%		Parks & Burrus (1987). Digital Filter Design. New York:
%		John Wiley & Sons, Inc.


% Copyright (C) 1999 Paul Kienzle <pkienzle@users.sf.net>
% Copyright (C) 2003 Doug Stewart <dastew@sympatico.ca>
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



if (nargin > 5 || nargin < 3 || nargout > 4)
	error('Number of input arguments is not correct.');
end

% interpret the input parameters
if ~(isscalar(n) && (n == fix (n)) && (n > 0))
	error ('cheby2: filter order N must be a positive integer');
end

stop = false;
digital = true;
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
		error ('cheby2: expected [high|stop] or [s|z]');
	end
end

if ~((numel(w) <= 2) && (size(w,1) == 1 || size(w,2) == 1))
	error ('cheby2: frequency must be given as WC or [WL, WH]');
elseif ((numel(w) == 2) && (w(2) <= w(1)))
	error ('cheby2: W(1) must be less than W(2)');
end

if digital && ~all((w >= 0) & (w <= 1))
	error ('cheby2: all elements of W must be in the range [0,1]');
elseif ~digital && ~all(w >= 0)
	error ('cheby2: all elements of W must be in the range [0,inf]');
end

if ~(isscalar (rs) && isnumeric(rs) && (rs >= 0))
	error ('cheby2: stopband attenuation RS must be a non-negative scalar');
end

% Prewarp to the band edges to s plane
if (digital)
	T = 2;       % sampling frequency of 2 Hz
	w = 2 / T * tan (pi * w / T);
end

% Generate splane poles and zeros for the Chebyshev type 2 filter
% From: Stearns, SD; David, RA; (1988). Signal Processing Algorithms.
%       New Jersey: Prentice-Hall.
C = 1;  % default cutoff frequency
lambda = 10^(rs / 20);
phi = log(lambda + sqrt(lambda^2 - 1)) / n;
theta = pi * ([1:n] - 0.5) / n;
alpha = -sinh(phi) * sin(theta);
beta = cosh(phi) * cos(theta);
if rem(n, 2)
	% drop theta==pi/2 since it results in a zero at infinity
	zero = 1i * C ./ cos(theta([1:(n - 1) / 2, (n + 3) / 2:n]));
else
	zero = 1i * C ./ cos(theta);
end
pole = C ./ (alpha.^2 + beta.^2) .* (alpha - 1i * beta);

% Compensate for amplitude at s=0
% Because of the vagaries of floating point computations, the
% prod(pole)/prod(zero) sometimes comes out as negative and
% with a small imaginary component even though analytically
% the gain will always be positive, hence the abs(real(...))
gain = abs(real(prod(pole)/prod(zero)));

% splane frequency transform
[zero, pole, gain] = sftrans(zero, pole, gain, w, stop);

% Use bilinear transform to convert poles to the z plane
if (digital)
	[zero, pole, gain] = bilinear(zero, pole, gain, T);
end

% convert to the correct output form
% note that poly always outputs a row vector
if (nargout <= 2)
	a = real (gain * poly(zero));
	b = real (poly(pole));
elseif (nargout == 3)
	a = zero(:);
	b = pole(:);
	c = gain;
else
	% output ss results
	[a, b, c, d] = zp2ss(zero, pole, gain);
end

