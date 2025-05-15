function [dlat,dlon] = ll2lim(lat,lon,minkm,maxxy,border,xylim)
% Determines X-Y limits of the map from points coordinates and options
% 	[DLAT,DLON]=LL2LIM(LAT,LON,MINKM,MAXXY,BORDER) computes latitude
%   limits DLAT=[LAT1,LAT2] and longitude limits DLON=[LON1,LON2] to include
%   all points defined by their coordinate vectors LAT and LON. Options are:
%       MINKM: minimum width/height size in km
%       MAXXY: maximum X/Y shape ratio
%      BORDER: adds a border in fraction from points limits
%
%   [DLAT,DLON]=LL2LIM(...,[LON0,LAT0,WIDTH]) overwrites other options and fixes
%   the center at LON0,LAT0, the width (in degree) and adjusts height to have a
%   XY aspect ratio of 1.
%       
% 	XYLIM=LL2LIM(...)
%
%   Author: F. Beauducel, IPGP
%   Created: 2019-05-29 in Yogyakarta (Indonesia)
%   Updated: 2025-03-17

if nargin > 5 && numel(xylim)>2
    [dlon,dlat] = xyw2lim(xylim,1/cosd(xylim(2)));
else
    dlat = [min(lat),max(lat)];
    dlon = [min(lon),max(lon)];
    lat0 = mean(dlat);

    % adjusts the minimum size
    if diff(dlat) < minkm/degkm
        dlat = dlat + [-.5,.5]*(minkm/degkm - diff(dlat));
    end
    if diff(dlon) < minkm/degkm(lat0)
        dlon = dlon + [-.5,.5]*(minkm/degkm(lat0) - diff(dlon));
    end

    % adjusts the maximum XY ratio
    xyratio = diff(dlon)*cosd(lat0)/diff(dlat);
    if xyratio < 1/maxxy
        dlon = dlon + [-.5,.5]*(diff(dlat)/maxxy - diff(dlon)*cosd(lat0));
    end
    if xyratio > maxxy
        dlat = dlat + [-.5,.5]*(diff(dlon)*cosd(lat0) - maxxy*diff(dlat));
    end

    % adds borders in %
    dlon = dlon + diff(dlon)*border*[-1,1]/cosd(lat0);
    dlat = dlat + diff(dlat)*border*[-1,1];
end

% outputs xylim
if nargout == 1
	dlat = [dlon,dlat];
end
