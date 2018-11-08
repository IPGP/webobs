function  [a,b,c,d] = cheby1(n,rp,w,varargin)

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
if ~(isscalar(n) && (n == fix(n)) && (n > 0))
	error('cheby1: filter order N must be a positive integer');
end

stop = false;
digital = true;
for i = 1:numel(varargin)
	switch (varargin{i})
	case 's'
		digital = false;
	case 'z'
		digital = true;
	case {'high', 'stop'}
		stop = true;
	case {'low', 'pass'}
		stop = false;
	otherwise
	      error ('cheby1: expected [high|stop] or [s|z]');
	end
end

if ~(numel(w) <= 2 && (size(w,1) == 1 || size(w,2) == 1))
	error ('cheby1: frequency must be given as WC or [WL, WH]');
elseif ((numel(w) == 2) && (w(2) <= w(1)))
	error ('cheby1: W(1) must be less than W(2)');
end

if digital && ~all((w >= 0) & (w <= 1))
	error ('cheby1: all elements of W must be in the range [0,1]');
elseif ~digital && ~all(w >= 0)
	error ('cheby1: all elements of W must be in the range [0,inf]');
end

if ~(isscalar (rp) && isnumeric(rp) && (rp >= 0))
	error ('cheby1: passband ripple RP must be a non-negative scalar');
end

% Prewarp to the band edges to s plane
if digital
	T = 2;       % sampling frequency of 2 Hz
	w = 2 / T * tan(pi * w / T);
end

% Generate splane poles and zeros for the Chebyshev type 1 filter
C = 1;  % default cutoff frequency
epsilon = sqrt(10^(rp / 10) - 1);
v0 = asinh(1 / epsilon) / n;
pole = exp(1i * pi * [-(n - 1):2:(n - 1)] / (2 * n));
pole = -sinh(v0) * real(pole) + 1i * cosh(v0) * imag(pole);
zero = [];

% compensate for amplitude at s=0
gain = prod(-pole);
% if n is even, the ripple starts low, but if n is odd the ripple
% starts high. We must adjust the s=0 amplitude to compensate.
if rem(n, 2) == 0
	gain = gain / 10^(rp / 20);
end

% splane frequency transform
[zero, pole, gain] = sftrans(zero, pole, gain, w, stop);

% Use bilinear transform to convert poles to the z plane
if (digital)
	[zero, pole, gain] = bilinear(zero, pole, gain, T);
end

% convert to the correct output form
% note that poly always outputs a row vector
if (nargout <= 2)
	a = real(gain * poly(zero));
	b = real(poly(pole));
elseif (nargout == 3)
	a = zero(:);
	b = pole(:);
	c = gain;
else
	% output ss results
	[a, b, c, d] = zp2ss(zero, pole, gain);
end


