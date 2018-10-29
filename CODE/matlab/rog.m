function c=rog(m)
%ROG Red-Orange-Green colormap.
%
%	Author: F. Beauducel, WEBOBS/IPGP.
%	Created: 2017-10-09, Paris.
%	Updated: 2018-07-23
%

if nargin == 0
	m = 64;
end

c = zeros(m,3);
mc = round(m/4);

% red color: red -> orange
c(:,1) = [linspace(1,1,mc),linspace(1,0,m - mc)]';
% green color: orange -> green
c(:,2) = [linspace(0,0.7,mc),linspace(0.7,1,m - mc)]';
