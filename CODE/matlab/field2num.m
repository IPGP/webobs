function y = field2num(x,f,y0,varargin)
%FIELD2NUM Convert structure field to number
%	FIELD2NUM(X,FIELD) checks existance of structure field X.(FIELD) and
%	converts the string into a scalar, vector or matrix of numerical value.
%
%	FIELD2NUM(X,FIELD,Y0) returns Y0 value if the conversion fails (default
%	is empty).
%
%	FIELD2NUM(X,FIELD,Y0,'notempty') returns also Y0 if X.(FIELD) is empty.
%
%	There is some specific FIELD names:
%
%	        *_RGB : a vector of 3 values R,G,B between 0 and 1 to set a color,
%	   or *_COLOR : allows HTML color name (see htm2rgb.m for available colors)
%	       *_DATE : converts the value to datenum
%	   *_COLORMAP : colormap name or .cpt filename
%	      *_ALPHA : scalar or 2-element vector between 0 and 1
%
%	The field value is usually a string of numerical value but it can content
%	simple arithmetics (multiplication, division, addition, substraction).
%
%	It is also possible to express time duration using the syntax aaaB, where
%	aaa is a number (minimum 1 digit) and B is one of the following letters:
%	's' for second, 'n' for minute, 'h' for hour, 'd' for day, 'w' for week,
%	'm' for month (30 days), and 'y' for year (365.25 days). The value will
%	be converted in days.
%
%	FIELD2NUM uses SSTR2NUM function (secure STR2NUM).
%
%
%	 Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2015-09-07 at Pos Dukono, Halmahera Utara (Indonesia)
%	Updated: 2021-03-30

D = struct('s',1/86400,'n',1/1440,'h',1/24,'d',1,'w',7,'m',30,'y',365.25);

trueval = any(strcmpi(varargin,'val')); % for debugging only (undocumented)
notempty = any(strcmpi(varargin,'notempty'));

if isstruct(x) && nargin > 1 && isfield(x,f) && (~isempty(x.(f)) || ~notempty)
	val = x.(f);
	if ischar(val)
		% RGB or color name
		if ~isempty(regexp(f,'_(RGB|COLOR)$')) && numel(str2num(val)) ~= 3
			y = htm2rgb(val);

		% any datenum compatible date
		elseif ~isempty(regexp(f,'_DATE$')) && ~isempty(val)
			try
				y = isodatenum(val);
			catch
				try
					y = datenum(val);
				catch
					fprintf('WEBOBS{field2num}: ** WARNING ** cannot convert %s key value (%s) to datenum...\n',f,val);
					y = sstr2num(val);
				end
			end

		% colormap name or .cpt filename
		elseif ~isempty(regexp(f,'COLORMAP$'))
			if ~isempty(regexpi(val,'\.cpt$')) && exist(val,'file')
				y = cpt2cmap(val);
			else
				y = sstr2num(val);
				if size(y,2) ~= 3
					fprintf('WEBOBS{field2num}: ** WARNING ** cannot import %s = "%s" colormap. Use defaut...\n',f,val);
					if nargin > 2
						y = y0;
					else
						y = spectral(256);
					end
				end
			end

		% opacity scalar or 2-element vector
		elseif ~isempty(regexp(f,'_ALPHA$'))
			y = val;
			if isscalar(y)
				y = repmat(y,1,2); % allows scalar definition of opacity
			end
			if numel(y) < 2 || any(~isinto(y,[0,1]))
				fprintf('%s: ** Warning: unvalid %s value (%s). Using default (0,1).\n',f,val);
				y = [0,1];
			end

		% time duration (converted in days)
		% [NOTE]: this test must be located after the color names to avoid NaN
		% when color name ends with one of the suffix letter...
		elseif ~isempty(regexp(val,'[snhdwmy]$'))
			y = str2double(val(1:end-1))*D.(val(end));

		elseif trueval
			y = str2num(val);
		else
			y = sstr2num(val);
		end
	else
		y = val;
	end
else
	if nargin > 2 || (isfield(x,f) && isempty(x.(f)) && notempty)
		y = y0;
	else
		y = [];
	end
end
