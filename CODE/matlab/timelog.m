function timelog(s,f)
%TIMELOG Display time log
%       TIMELOG(S,1) for start and TIMELOG(S,2) for end, where S is the PROC name string.
%
%
%       Author: François Beauducel, WEBOBS/IPGP
%       Created: 2001-06-14 in Guadeloupe (French West Indies)
%       Updated: 2016-07-10

if nargin < 2
    f = 1;
end
startend = {'started';'ended'};
fprintf('\n=== %s : Process %s on %s\n',s,startend{(f)},datestr(now));
