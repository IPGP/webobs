function y = cleanpicks(x,F)
%CLEANPICKS Removes picks data.
%   CLEANPICKS(X) replaces by NaN the 1% of min and max data from vector X,
%	using a	median-style filter and after removing a linear trend.
%
%	CLEANPICKS(X,N) removes N% of extreme data.
%
%	CLEANPICKS(X,FILTER) uses F as a structure containing various filters
%
%	See also MINMAX, RSTD, DETREND.
%
%	Author: F. Beauducel <beauducel@ipgp.fr> / WEBOBS
%	Created: 2013-03-07
%	Updated: 2019-05-21

filter1 = 'PICKS_CLEAN_PERCENT';
filter2 = 'PICKS_CLEAN_STD';

if nargin < 2
	F.(filter1) = 1;
else
	if isscalar(F) && isnumeric(F)
		F.(filter1) = F;
	else
		n = field2num(F,filter1,0);
	end
end

% set output equal to input
y = x;

% removes linear trend
x = detrend(x);

% --- median min/max filter
if n < 0 || n >= 100
	error('N must be a percentage >= 0 and  < 100');
end
if numel(x)*n >= 1
	m = minmax(x,[n/100 1-n/100]);
	y(x < m(1) | x > m(2)) = NaN;
end


% --- STD filter
n = field2num(F,filter2,0);
if n < 0
	error('N must be a positive for %s filter.',filter2);
end
if n > 0
	y(abs(x) > n*rstd(x)) = NaN;
end


