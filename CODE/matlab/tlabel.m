function tlabel(tlim,tu,varargin)
%TLABEL Adds a time/date x-label
%       TLABEL(TLIM,TU) adds xlabel to current graph with date and time TLIM = [T1,T2]
%       and TU indication.

xlabel(sprintf('{\\bf%s - %s} {\\it%+g}',datestr(tlim(1)),datestr(tlim(2)),tu),varargin{:});
