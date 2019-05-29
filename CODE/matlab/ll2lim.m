function [dlat,dlon] = ll2lim(lat,lon,minkm,maxxy,border)
% Determines X-Y limits of the map from NODE's coordinates
% 	[DLAT,DLON]=LL2LIM(...)
% 	XYLIM=LL2LIM(...)

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

% outputs xylim
if nargout == 1
	dlat = [dlon,dlat];
end
