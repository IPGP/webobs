function y=roundsd(x,n,method)
%ROUNDSD Round with fixed significant digits
%	ROUNDSD(X,N) rounds the elements of X towards the nearest number with
%	N significant digits.
%
%	ROUNDSD(X,PIVOTS) rounds the elements of X towards the nearest number
%	based on digits in the PIVOTS vector.
%
%	ROUNDSD(...,METHOD) uses following methods for rounding:
%		'round' - nearest (default)
%		'floor' - towards minus infinity
%		'ceil'  - towards infinity
%		'fix'   - towards zero
%
%	Examples:
%		roundsd(0.012345,3) returns 0.0123
%		roundsd(12345,2) returns 12000
%		roundsd(12.345,3,'ceil') returns 12.4000
%
%	See also Matlab's functions ROUND, ROUND10, FLOOR, CEIL, FIX, and 
%	ROUNDN (Mapping Toolbox).
%
%	Author: François Beauducel <beauducel@ipgp.fr>
%	  Institut de Physique du Globe de Paris
%
%	Acknowledgments: Edward Zechmann, Daniel Armyr, Yuri Kotliarov
%
%	Created: 2009-01-16
%	Updated: 2023-04-19

%	Copyright (c) 2023, François Beauducel, covered by BSD License.
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

if nargin < 2
	error('Not enough input arguments.')
end

if nargin > 3
	error('Too many input arguments.')
end

if ~isnumeric(x)
		error('X argument must be numeric.')
end

if ~isnumeric(n) || any(n < 1) || any(mod(n,1))
	error('N or PIVOTS argument must be positive integers.')
end

opt = {'round','floor','ceil','fix'};

if nargin < 3
	method = opt{1};
else
	if ~ischar(method) || ~any(ismember(opt,method))
		error('METHOD argument is invalid.')
	end
end

% The generic formula was simple:
%    og = 10.^(floor(log10(abs(x)) - n + 1));
%    y = feval(method,x./og).*og;
% BUT we must treat separately positive and negative exponents, 
% because of numerical noise, i.e.:
%    3.55/0.1 - 35.5 is -7.105427357601e-15
%    3.55*10 - 35.5 is 0

if length(n) > 1
	pivots = n;
	n = floor(log10(max(n))) + 1;
else
	pivots = [];
end
e = floor(log10(abs(x)) - n + 1);
og = 10.^abs(e);
y = roundg(x./og,method,pivots).*og;
k = (e<0);
if any(k)
	y(k) = roundg(x(k).*og(k),method,pivots)./og(k);
end	
y(x==0) = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y=roundg(x,method,pivots)
if isempty(pivots)
	y = feval(method,x);
else
	xp = [pivots(end)/10,pivots,pivots(1)*10];
	yp = 0:length(xp)-1;
	y = interp1(yp,xp,feval(method,interp1(xp,yp,x)));
end
