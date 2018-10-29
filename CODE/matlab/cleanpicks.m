function y = cleanpicks(x,n)
%CLEANPICKS Removes picks data.
%   CLEANPICKS(X) replaces by NaN the 1% of min and max data from vector X,
%	using a	median-style filter.
%
%	CLEANPICKS(X,N) removes N% of extreme data.
%
%	See also MINMAX.
%
%	Author: F. Beauducel <beauducel@ipgp.fr>
%	Created: 2013-03-07
%	Updated: 2016-05-30

if nargin < 2
	n = 1;
end

if n < 0 || n >= 100
	error('N must be a percentage >= 0 and  < 100');
end

y = x;

if numel(x)*n >= 1
	m = minmax(x,[n/100 1-n/100]);
	y(x < m(1) | x > m(2)) = NaN;
end
