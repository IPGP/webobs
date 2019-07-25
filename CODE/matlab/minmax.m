function y=minmax(varargin)
%MINMAX	Generalized median filter.
%	Y=MINMAX(X) returns a 2 element vector Y = [min(X) max(X)]. Minimum and
%	maximum values of X(:) are computed after excluding any NaN values.
%
%	Y=MINMAX(X,N) with N between 0 and 1, returns generalized median filter
%	value of X(:), e.g., it sorts elements of X then interpolates at 
%	(100*N) % rank position. N can be scalar, vector or matrix, so Y will 
%	have the same size as N.
%
%	MINMAX(...,'linear') returns linear interpolation into values of X.
%
%	MINMAX(...,'finite') returns minimum and maximum of X using only finite
%	values (-Inf and Inf ignored).
%
%	Examples:
%
%		MINMAX(X,0) returns the minimum value of X elements.
%
%		MINMAX(X,1) returns the maximum value of X elements.
%
%		MINMAX(X,0.5) returns the median value of X elements. This is the
%		equivalent of MEDIAN(X(:)).
%
%		MINMAX(X,0.9) returns maximum value of X after excluding the 10%
%		highest value elements.
%
%		MINMAX(X,[0 1]) is the same as MINMAX(X).
%
%		MINMAX(X,[0.01 0.99]) is a convenient way to compute automatic 
%		scale of X when samples are noisy, since it filters the 1% elements
%		with extreme values. It may be used for color scaling with CAXIS or
%		for plot scaling with set(gca,'YLim',...).
%
%	See also MIN, MAX and MEDIAN.
%
%	Author: Fran�ois Beauducel <beauducel@ipgp.fr>
%	Created: 1996, in Paris (France)
%	Updated: 2019-07-25

%	Copyright (c) 2019, Fran�ois Beauducel, covered by BSD License.
%	All rights reserved.
%
%
%	Revision history:
%
%	[2019-07-25]
%		- adds options
%	
%	[2013-02-27]
%		- works with X scalar
%
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

if nargin < 1
	error('Not enough input arguments.');
end

if any(~isnumeric(varargin{1}))
	error('X must be numeric.')
else
	x = varargin{1};
end

n = [0 1];
if nargin > 1
	if all(isnumeric(varargin{2}))
		n = varargin{2};
		if any(~isnumeric(n)) || any(n < 0 | n > 1)
			error('N must contain values between 0 and 1.')
		end
	end
end

if nargin < 3
	opt = 'nearest';
else
	if any(strcmpi(varargin,'nearest'))
		opt = 'linear';
	end
end

% removes NaN values
x = x(~isnan(x));

% removes Inf values
if any(strcmpi(varargin,'finite'))
	x = x(isfinite(x));
end

if isempty(x)
	y = nan(size(n));
elseif length(x) == 1
	y = x*ones(size(n));
else
	y = interp1(sort(x),n*(length(x)-1) + 1,opt);
end

