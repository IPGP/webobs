function s=strjoin(c,d)
%STRJOIN Join strings
%	STRJOIN(C,DELIMITER) joins cell elements in C using string D as delimiter.
%	STRJOIN(C) concatenates elements without delimiter.
%
%	Author: F. Beauducel, IPGP

if nargin < 2
	d = '';
end
n = numel(c);
ss = cell(2,n);
ss(1,:) = reshape(c,1,n);
ss(2,1:n-1) = {d};
ss{end} = '';
s = [ss{:}];
