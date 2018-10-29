function extaxes(h,mm)
%EXTAXES Extend axe
%   EXTAXES extends current axe horizontaly to fit the figure width
%   with a default minimum margin of 0.07 (7%).
%
%   EXTAXES(H) extends axe H.
%
%   EXTAXES(H,MM) uses minimum margin fraction vector MM = [LEFT RIGHT]
%   to specify different left/right margins.
%
%   EXTAXES(H,LRUD) extends the axe size by a fraction of it, using a 4-element
%   vector LRUD = [LEFT,RIGHT,UP,DOWN]. Use 0 value to fix any of axe limit.
%
%
%   Author: F. Beauducel, OVSG-IPGP
%   Created: 2005
%   Updated: 2017-08-02

if nargin < 1
	h = gca;
end

if nargin < 2
	mm = .07;	% Minimum margin
end

if ~all(isnumeric(mm)) || ~any(numel(mm) == [1,2,4]) || any(mm) < 0 || any(mm) > 1 
	error('MM argument must be scalar, 2 or 4-element vector between 0 and 1.');
end

pos = get(h,'Position');

switch numel(mm)
case {1,2}
	if numel(mm) == 1
		mm = repmat(mm,1,2);
	end
	mm(mm == 0) = .005;
	set(h,'Position',[mm(1),pos(2),1-sum(mm),pos(4)]);
case 4
	set(h,'Position',[pos(1) - mm(1)*pos(3), ...
	                  pos(2) - mm(2)*pos(4), ...
			  pos(3)*(1 + sum(mm(1:2))), ...
			  pos(4)*(1 + sum(mm(3:4)))]);
end


