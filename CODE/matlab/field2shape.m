function y = field2shape(x,f)
%FIELD2SHAPE Convert structure field to shape matrix 
%	FIELD2SHAPE(X,FIELD) checks existance of structure field X.(FIELD) and
%	loads the shape in corresponding file. If the file does not exist or
%	FIELD is invalid or empty, it returns an empty matrix.
%
%	 Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2019-10-09 at Yogyakarta, Indonesia
%	Updated: 2019-10-09


if isstruct(x) && nargin > 1 && isfield(x,f) && exist(x.(f),'file')
	y = ibln(x.(f));
else
	y = [];
end
