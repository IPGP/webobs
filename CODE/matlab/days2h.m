function varargout=days2h(d,varargin)
%DAYS2H Human reading of time duration.
%	DAYS2H(D) returns a human readable string equivalent of a time duration
%	D expressed in days.
%
%	D can be a scalar, a vector or a matrix of numbers. In these last cases
%	DAYS2H returns a cell of string of the same size (vector of matrix), 
%	instead of a string.
%
%	DAYS2H(...,'round') limits the output at the first order value.
%
%	DAYS2H(...,'short') uses short names (1 or 2 letters) for time units.
%
%	DAYS2H(...,'week') adds the 'week' unit, so that DAYS2H(7,'week') will
%	return '1 week' instead of '7 days'.
%
%	Examples:
%	   DAYS2H(1/1440) returns '1 minute'
%	   DAYS2H(8.5) returns '8 days 12 hours'
%	   DAYS2H(10000) returns '~27 years 4 months 25 days'
%	   DAYS2H(8.5,'week') returns '1 week 1 day 12 hours'
%	   DAYS2H(10.^(-6:6)','round') returns a cell of strings:
%	     '~86 milliseconds'
%	     '~1 second'
%	     '~9 seconds'
%	     '~1 minute'
%	     '~14 minutes'
%	     '~2 hours'
%	     '1 day'
%	     '10 days'
%	     '~3 months'
%	     '~3 years'
%	     '~27 years'
%	     '~3 centuries'
%	     '~3 millennia'
%
%
%	Author: F. Beauducel <beauducel@ipgp.fr>
%	Created: 2015-11-13 in Paris, France
%	Updated: 2015-12-26

%	Copyright (c) 2015, François Beauducel, covered by BSD License.
%	All rights reserved.
%
%	Redistribution and use in source and binary forms, with or without 
%	modification, are permitted provided that the following conditions are 
%	met:
%
%	   * Redistributions of source code must retain the above copyright 
%	     notice, this list of conditions and the following disclaimer.
%	   * Redistributions in binary form must reproduce the above copyright 
%	     notice, this list of conditions and the following disclaimer in 
%	     the documentation and/or other materials provided with the 
%	     distribution
%	                           
%	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%	IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED 
%	TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
%	PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
%	OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
%	SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
%	LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
%	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
%	THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
%	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
%	OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

if nargin < 1
	error('Not enough input argument.')
end

% table of units equivalent in days
T = { ...
	365242    ,  'millennium',    'millennia', 'ky';
	36524     ,     'century',    'centuries', 'c';
	365       ,        'year',        'years', 'yr';
	31        ,       'month',       'months', 'mo';
	7         ,        'week',        'weeks', 'wk';
	1         ,         'day',         'days', 'd';
	1/24      ,        'hour',        'hours', 'hr';
	1/1440    ,      'minute',      'minutes', 'mn';
	1/86400   ,      'second',      'seconds', 's';
	1/86400000, 'millisecond', 'milliseconds', 'ms';
};
R = {'','~'};	% prefix for approximation values

% options
opt_short = any(strcmpi(varargin,'short'));
opt_round = any(strcmpi(varargin,'round'));
opt_week = any(strcmpi(varargin,'week'));

% deletes the week unit (default)
if ~opt_week
	T(strcmp(T(:,2),'week'),:) = [];
end

% initiate the output as a cell of strings
s = cell(size(d));
time = cat(1,T{:,1});	% extracts the first colum to simplify the code

for n = 1:numel(d)
	dreal = abs(d(n))./time;
	if opt_round
		dd = round(dreal);
		k = find(dd>0,1);	% first occurrence of unit greater or equal to 1
		s{n} = sprintf('%s%d %s',R{2 - (dd(k)==dreal(k))},dd(k),T{k,unit(dd(k),opt_short)});
	else
		dd = floor(dreal);
		k = find(dd>0,1);	% first occurrence of unit greater than 1
		if ~isempty(k)
			a = dreal(k);
			s{n} = R{1 + (k<=4)};	% approximation sign for units greater than day
			for kk = k:length(time)
				dk = floor(a + time(end));
				if dk > time(end)
					s{n} = sprintf('%s%d %s ',s{n},dk,T{kk,unit(dk,opt_short)});
					if kk < length(time)
						a = max((a - dk)*time(kk)/time(kk+1),0);
					end
				else
					break;
				end
			end
			s{n} = deblank(s{n});
		else
			s{n} = sprintf('%g %s',dreal(end),T{end,2});
		end
	end
end

if numel(d) == 1
	s = char(s);
end

if nargout == 0
	disp(s)
else
	varargout{1} = s;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function k = unit(x,short)
if short
	k = 4;
else
	k = 2 + (x>1);
end
