function s = field2cell(x,f,varargin)
%FIELD2STR Convert structure field to string
%	FIELD2CELL(X,FIELD) checks existance of structure field X.(FIELD) and
%	returns the content as cell (must uses correct Matlab syntax).
%
%	FIELD2CELL(X,FIELD,DEFAULT,...) returns additional arguments as 
%	elements of a cell if the convertion fails (default is empty).
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2018-04-23 in Mahébourg, Mauritius
%	Updated: 2018-04-23

if nargin < 2 && ~isstruct(x) & ~ischar(f)
	error('Arguments X must be a structure and FIELD a string.')
end

s = varargin;

if isfield(x,f)
	try
		eval(sprintf('s={%s};',strrep(x.(f),'''''','''')));
	catch
		fprintf('WEBOBS{%s}: ** Warning: invalid %s values... using default.\n',mfilename,f);
	end
end

