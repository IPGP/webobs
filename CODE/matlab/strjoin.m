function s=strjoin(c,d)
%STRJOIN Join strings
%	STRJOIN(C,DELIMITER) joins non-empty elements in cell C using string D 
%   as delimiter.
%	STRJOIN(C) concatenates elements without delimiter.
%
%	Author: F. Beauducel, IPGP
%   Updated: 2025-02-17

if nargin < 2
	d = '';
end

c(cellfun(@isempty,c)) = []; % remove empty elements
n = numel(c);
ss = cell(2,n);
ss(1,:) = reshape(c,1,n);
ss(2,1:n-1) = {d};
ss{end} = '';
s = [ss{:}];
