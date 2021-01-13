	function datetick2(varargin)
%DATETICK2 Date formatted tick labels.
%   DATETICK2(TICKAXIS,DATEFORM,...) works like DATETICK function, except:
%	- it accepts DATEFORM value of -1 for automatic format,
%      - it forces 'keeplimits' option,
%      - it forces 'keepticks' option when datetick fails.
%
%
%   See also DATETICK, DATESTR, DATENUM.
%
%   Author: F. Beauducel, IPGP/WEBOBS
%   Created: 2009-10-07
%   Updated: 2021-01-01

v = varargin;

% to accept DATEFORM = -1 for automatic
if length(v) > 1
	if v{2} == -1
		v(2) = [];
	end
end

xticks = get(gca,'XTick');
datetick(v{:},'keeplimits');

% checks if datetick succeeded...
if numel(get(gca,'XTick')) < 3
	set(gca,'XTick',xticks); % reset original X ticks
	datetick(v{1},29,'keeplimits','keepticks');
end
