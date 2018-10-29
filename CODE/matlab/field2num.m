function y = field2num(x,f,y0,varargin)
%FIELD2NUM Convert structure field to number
%	FIELD2NUM(X,FIELD) checks existance of structure field X.(FIELD) and
%	converts the string into vector.
%
%	FIELD2NUM(X,FIELD,Y0) returns Y0 value if the conversion fails (default
%	is empty).
%
%	FIELD2NUM(X,FIELD,Y0,'notempty') returns also Y0 if X.(FIELD) is empty.
%
%	There is some specific FIELD names:
%
%	      *_RGB or
%	      *_COLOR : allows HTML color name (see htm2rgb.m for available colors)
%	       *_DATE : converts the value to datenum
%	    *COLORMAP : colormap name or .cpt filename
%	      *_ALPHA : scalar or 2-element vector between 0 and 1
%
%	FIELD2NUM uses SSTR2NUM function (secure STR2NUM).
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2015-09-07 at Pos Dukono, Halmahera Utara, Indonesia
%	Updated: 2017-07-27

val = any(strcmpi(varargin,'val'));
notempty = any(strcmpi(varargin,'notempty'));

if isstruct(x) && nargin > 1 && isfield(x,f) && (~isempty(x.(f)) || ~notempty)
	if ischar(x.(f))
		if ~isempty(regexp(f,'_(RGB|COLOR)$')) && numel(str2num(x.(f))) ~= 3
			y = htm2rgb(x.(f));

		elseif ~isempty(regexp(f,'_DATE$'))
			try
				y = isodatenum(x.(f));
			catch
				try
					y = datenum(x.(f));
				catch
					fprintf('WEBOBS{field2num}: ** WARNING ** cannot convert %s key value (%s) to datenum...\n',f,x.(f));
					y = sstr2num(x.(f));
				end
			end

		elseif ~isempty(regexp(f,'COLORMAP$'))
			if ~isempty(regexpi(x.(f),'\.cpt$')) && exist(x.(f),'file')
				y = cptcmap(x.(f));
			else
				y = sstr2num(x.(f));
				if size(y,2) ~= 3
					y = jet(256);
				end
			end

		elseif ~isempty(regexp(f,'_ALPHA$'))
			y = x.(f);
			if isscalar(y)
				y = repmat(y,1,2); % allows scalar definition of opacity
			end
			if numel(y) < 2 || any(~isinto(y,[0,1]))
				fprintf('%s: ** Warning: unvalid %s value (%s). Using default (0,1).\n',f,x.(f));
				y = [0,1];
			end

		elseif val
			y = str2num(x.(f));
		else
			y = sstr2num(x.(f));
		end
	else
		y = x.(f);
	end
else
	if nargin > 2 || (isfield(x,f) && isempty(x.(f)) && notempty)
		y = y0;
	else
		y = [];
	end
end
