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

ST = dbstack;
n = min(2,length(ST));

fprintf(['%s - WEBOBS{%s}: ' s],datestr(now),ST(n).name,varargin{:})
