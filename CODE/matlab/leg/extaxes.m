function extaxes(h,mm)
%EXTAXES Extend axe
%   EXTAXES extends current axe horizontaly to fit the figure width
%   with a default minimum margin of 0.07 (7%).
%
%   Author: F. Beauducel, OVSG-IPGP
%   Created: 2005
%   Updated: 2010-07-19

if nargin < 1
	h = gca;
end
if nargin < 2
	mm = .07;	% Minimum margin
end

pos = get(h,'Position');
%set(h,'Position',[mm,pos(2),pos(3)+2*(pos(1)-mm),pos(4)]);
set(h,'Position',[mm,pos(2),1-2*mm,pos(4)]);
