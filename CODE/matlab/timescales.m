function varargout=timescales(varargin)
%TIMESCALES Returns information about time scales
%       P=TIMESCALES(P) interprets the P.TIMESCALELIST (coma-separated key list) and 
%       other PROC's variables and returns a cell array of date limits in P.DATELIST.
%
%	TIMESCALES(EXT) where EXT is a single key string, returns the corresponding
%	long string name. Example: timescales('2y') returns '2 years'.
%       
%	keys are short strings defining a timescale:
%	   'xT': a duration until now, where xx is a number and T a letter indicating
%	         the time base (see list in code)
%	   'rx': from a reference date (defined in P.REFx_DATE) until now
%	  'all': means all available data (date limits will be set to NaN)
%
%	Note that proc's key TIMESCALE_TRUEVALUE should contains a false string ('NO')
%	to get the former behavior, i.e., a month is approximated by 30 days and a year
%	by 365.25 days. Default is to compute true time scales, that is, variable month 
%	length (from 28 to 31 days), and variable year length (from 365 to 366 days).
%
%
%   Authors: F. Beauducel, D. Lafon, WEBOBS/IPGP
%   Created: 2010-06-12 in Paris, France
%   Updated: 2017-12-12


if nargin < 1
	error('WEBOBS{timescales}: Must specify a key string or a PROC structure');
end

if isstruct(varargin{1})
	P = varargin{1};
	P.TIMESCALELIST = split(field2str(P,'TIMESCALELIST'),',')';

	for n = 1:length(P.TIMESCALELIST)
		P.DATELIST{n} = timekey(P.TIMESCALELIST{n},P);
	end
	varargout{1} = P;
else
	if isempty(varargin{1})
		varargout{1} = '';
	else
		varargout{1} = timekey(varargin{1});
	end
end


% =============================================================================
% =============================================================================
function varargout=timekey(key,P)

N = struct('s','second','n','minute','h','hour','d','day','w','week','m','month','y','year','l','last');
D = struct('s',1/86400,'n',1/1440,'h',1/24,'d',1,'w',7,'m',30,'y',365.25);

name = '';
datelim = nan(1,2);

% for backward compatibility (replaces some of old "timescales.conf" definitions)
key = regexprep(key,'a$|an$|yr$','y');
key = regexprep(key,'j$','d');

ok = 1;

switch key(end)
% all data and last events => keep NaN and let readproc do the job from data
case 'l'
	if strcmp(key,'all')
		name = 'All data';
	else
		n = str2num(key(1:(end-1)));
		if n > 0
			name = sprintf('Last %d',n);
		else
			ok = 0;
		end
	end

% constant periods of time
case {'s','n','h','d','w','m','y'}
	if length(key) > 1 && isfield(D,key(end))
		k = key(end);
		d = str2double(key(1:end-1));
		name = sprintf('%g %s',d,plural(d,N.(k)));
		if nargin > 1
			datelim = P.NOW - [d*D.(k),0];
			% but some periods are not constant...
			if isok(P,'TIMESCALE_TRUEVALUE',1)
				tv = datevec(P.NOW);
				switch key(end)
				case 'y'
					datelim = [datenum([tv(1)-d,tv(2:end)]),P.NOW];
				case 'm'
					datelim = [datenum([tv(1)+floor((tv(2)-d-1)/12),mod(tv(2)-d-1,12)+1,tv(3:end)]),P.NOW];
				end
			end

		end
	else
		ok = 0;
	end

otherwise
	if key(1) == 'r' && length(key) > 1
		name = 'Ref.';
		if nargin > 1
			if strcmp(key,'ref')
				sref = 'REF_DATE';
			else
				sref = sprintf('REF%s_DATE',key(2:end));
			end
			ref = field2num(P,sref);
			if isempty(ref)
				fprintf('WEBOBS{timescales}: ** WARNING ** "%s" in TIMESCALELIST but no %s defined...\n',key,sref);
			end
			datelim = [ref,P.NOW];
		else
			if ~strcmp(key,'ref')
				name = sprintf('Ref. %s',key(2:end));
			end
		end
	else
		ok = 0;
	end
end

if ~ok
	fprintf('WEBOBS{timescales): ** WARNING ** unknown format for key "%s"...\n',key);
end

if nargin > 1
	varargout{1} = datelim;
	
else
	varargout{1} = name;
end
