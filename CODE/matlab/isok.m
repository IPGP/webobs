function y = isok(x,f,v)
%ISOK Determine whether input means "OK"
%	ISOK(X) returns 1 if X is non-zero positive scalar, string 'YES', 'Y', 'OK' or 'ON'
%	(case insensitive), returns 0 otherwise.
%
%	ISOK(X,FIELD,V) will use field structure X.FIELD if exist and return optional default
%	value V if not exist.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2014-08-17
%	Updated: 2019-02-14


okstrings = {'y','yes','ok','on','oui','ya','si'};
notokstrings = {'n','no','ko','off','non','tidak'};
if nargin < 3
	v = false;
end

if isstruct(x)
	if nargin > 1 && isfield(x,f)
		x = x.(f);
	else
		x = 0;
	end
end

if ischar(x)
	xx = str2double(x);
else
	xx = x;
end

if (~isempty(xx) && ~isnan(xx) && xx > 0) || (ischar(x) && any(strcmpi(x,okstrings)))
	y = 1;
elseif ischar(x) && any(strcmpi(x,notokstrings))
	y = 0;
else
	y = v;
end
