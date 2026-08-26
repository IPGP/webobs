function wolog(s,varargin)
%WOLOG WebObs log
%   WOLOG(S) displays string S prefixed by timestamp and caller function name.
%
%   WOLOG(FORMAT, A, ...) works like FPRINTF function with a FORMAT string and
%   list of arguments A, ...
%
%   See FPRINTF.
%
%
%   Author: F. Beauducel, IPGP
%   Created: 2026-04-28 in La Plaine des Cafres, Réunion
%   Udated: 2026-08-26

ST = dbstack;
n = min(2,length(ST));
fun = strjoin(fliplr(cat(1,{ST(n:end).name})),':');
if nargin < 1
    s = '';
end

fprintf(['%s - WO{%s}: ' s],datestr(now),fun,varargin{:})