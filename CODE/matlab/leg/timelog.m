function timelog(s,f)
%TIMELOG Display time log
%       TIMELOG(S,1) for start and TIMELOG(S,2) for end, where S is station name string.
%
%       (c) F. Beauducel/WEBOBS, OVSG-IPGP, 2001-06-14

if nargin<2
    f = 1;
end
startend = {'started';'ended'};
disp(sprintf('\n=== %s : Process %s on %s\n',upper(s),startend{(f)},datestr(now)))
