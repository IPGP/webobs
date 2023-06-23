function datetick2(varargin)
%DATETICK2 Date formatted tick labels.
%   DATETICK2(TICKAXIS,DATEFORM,...) works like DATETICK function, except:
%      - it forces 'keeplimits' option,
%      - it forces 'keepticks' option for time interval between 2 and 100 days.
%
%    
%   See also DATETICK, DATESTR, DATENUM.
%
%   Author: F. Beauducel, IPGP/WEBOBS
%   Created: 2009-10-07
%   Updated: 2018-05-30

v = varargin;

% to accept DATEFORM = -1 for automatic
if length(v) > 1
	if v{2} == -1
		v(2) = [];
	end
end

opt = {'keeplimits'};

% get the time interval of axis
dt = diff(get(gca,[v{1},'lim']));
if dt > 2 && dt < 100
	opt = {opt{:},'keepticks'};
end

datetick(v{:},opt{:});

