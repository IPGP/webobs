function s = field2str(x,f,s0,varargin)
%FIELD2STR Convert structure field to string
%	FIELD2STR(X,FIELD) checks existence of structure field X.(FIELD) and
%	return the string content.
%
%	FIELD2STR(X,FIELD,S0) returns S0 string if the convertion fails (default
%	return value is empty).
%
%	FIELD2STR(X,FIELD,S0,'notempty') returns also S0 if X.(FIELD) is empty.
%
%	FIELD2STR(X,FIELD,{S0,S1,...}) accepts only the values in cell {S0,S1,...}
%	and returns default S0 if not.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2016-01-29 at BPPTKG, Yogyakarta Indonesia
%	Updated: 2020-11-19

if nargin < 2 && ~isstruct(x) && ~ischar(f)
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
	if nargin > 2 && ischar(s0) || (isfield(x,f) && isempty(x.(f)) && notempty)
		s = s0;
	else
		s = [];
	end
end

if nargin > 2 && iscell(s0) && ~isempty(s0) && (isempty(s) || ~ismember(s,s0))
	s = s0{1};
end
