function s = field2prog(x,f,s)
%FIELD2PROG Convert structure field to program
%	FIELD2PROG(X,FIELD,DEFAULT) checks existence of structure field X.(FIELD)
%   and returns the program if the file exists using 'which' system command,
%   otherwise use optional value DEFAULT (optional).
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2020-11-19 at BPPTKG, Yogyakarta Indonesia
%	Updated: 2026-09-11

if nargin < 2 && ~isstruct(x) && ~ischar(f)
	error('Arguments X must be a structure and FIELD a string.')
end

if nargin < 3
    s = '';
end
if isfield(x,f) && ~isempty(x.(f)) && ischar(x.(f))
	[status,w] = system(sprintf('which %s',x.(f)));
	if ~status && ~isempty(w)
		s = regexprep(w,'\n*$','');
	end
end
