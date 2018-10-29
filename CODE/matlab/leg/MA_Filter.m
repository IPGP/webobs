function [sf,jegarde] = MA_Filter(s,NFilter,NUnits,dt,FShape)

% Performs a simple non-causal (i.e. non-dephasing) moving average filtering
%   [sf,k] = MA_Filter(s,NFilter,NUnits,dt,FShape) where:
%       s = signal to be filtered,
%       NFilter = length of half-part of the MA filter (even or odd, does not matter)
%           expressed in unit of time,
%       NUnits = ration between unit of time for NFilter and for dt (e.g. if NFilter is 
%           expressed in minutes and dt in seconds, then NUnits = 60),
%       dt = sampling interval (in seconds),
%       FShape = 'dirichlet' or 'triangular'
%       sf = filtered signal (with edge effects)
%       k = selected indices of s to avoid border effects (use sf(k))

% François Beauducel, Lauriane Chardot and Dominique Gibert, december 2008

NFilter = NFilter*NUnits/dt+1;
switch lower(FShape)
    case 'dirichlet'
        filter = ones(1,NFilter);
    case 'triangular'
        filter = (1:NFilter);
    otherwise
        filter = 1;
        disp('Unknown filter shape')
end
filter = filter/sum(filter);

if any(size(s)==1)
	s = s(:);
end

% pre-allocating the final matrix
sf = ones(size(s));

for i = 1:size(s,2)

	% forward filtering followed by backward filtering to cancel phase shift
	tmp = conv(s(:,i),filter);
	tmp = conv(tmp(end-NFilter+1:-1:1),filter);
	sf(:,i) = tmp(end-NFilter+1:-1:1);

end

% Now: suppress edge effects
jegarde = NFilter+1:size(s,1)-NFilter;

