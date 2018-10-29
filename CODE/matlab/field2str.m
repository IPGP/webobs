function s = field2str(x,f,s0,varargin)
%FIELD2STR Convert structure field to string
%	FIELD2STR(X,FIELD) checks existance of structure field X.(FIELD) and
%	return the string content.
%
%	FIELD2STR(X,FIELD,S0) returns S0 string if the convertion fails (default
%	is empty).
%
%	FIELD2STR(X,FIELD,S0,'notempty') returns also S0 if X.(FIELD) is empty.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2016-01-29 at BPPTKG, Yogyakarta Indonesia
%	Updated: 2016-07-10

if nargin < 2 && ~isstruct(x) & ~ischar(f)
	error('Arguments X must be a structure and FIELD a string.')
end

notempty = any(strcmpi(varargin,'notempty'));

if isfield(x,f) && (~isempty(x.(f)) || ~notempty)
	if ischar(x.(f))
		s = x.(f);
	else
		s = num2str(x.(f));
	end
else
	if nargin > 2 || (isfield(x,f) && isempty(x.(f)) && notempty)
		s = s0;
	else
		s = [];
	end
end
