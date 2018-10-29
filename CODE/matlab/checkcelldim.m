function [N,s]=checkcelldim(C)
%CHECKCELLDIM Checks cell array dimensions
%	C=CHECKCELLDIM(C) returns cell array C with same vector length if necessary.
%
%	Author: Francois Beauducel <beauducel@ipgp.fr> / WEBOBS
%	Created: 2014-02-13


n = zeros(size(C));
for k = 1:numel(n)
	n(k) = length(C{k});
end
if length(unique(n)) > 1
	N = cell(size(C));
	m = min(n);
	fprintf('WEBOBS{checkcelldim}: Warning: cell array contains different vector length. Truncates to %d data...\n',m);
	for k = 1:numel(n)
		N{k} = C{k}(1:m);
	end
	s = 1;
else
	N = C;
	s = 0;
end
