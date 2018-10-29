function varargout = ipe2kml(kml,d,law1,law2)
%IPE2KML makes a KML of predicted seismic intensities.
%	IPE2KML(D,F,GMPE,GMICE) writes a KML file F of predicted intensities
%	for an earthquake D = [LAT,LON,DEP,MAG] using ground motion prediction
%	equation GMPE and ground motion to intensity conversion equation GMICE
%	(see gmpe.m and gmice.m for options).
%
%	Author: Francois Beauducel, WEBOBS
%	Created: 2014-05-01
%	Updated: 2015-06-11


% Shaded JET colormap 
sjet = jet(256);
jj = repmat(linspace(0,.9,length(sjet)),3,1)';
sjet = sjet.*jj + (1-jj);

% colormap is interpolated for 10-level of intensities
map = floor(interp1(sjet,linspace(1,255,10))*255);
% transparency from 50% to 75%
alpha = floor(linspace(128,196,10)');


[path,nam,ext] = fileparts(kml);
fid = fopen(kml,'wt');

% KML header (definition of colors for each level)
fprintf(fid,'<?xml version="1.0" encoding="UTF-8"?>\n');
fprintf(fid,'<kml xmlns="http://www.opengis.net/kml/2.2">\n');
fprintf(fid,'<Document>\n');
fprintf(fid,'<name>Earthquake %s</name>\n',nam);
fprintf(fid,'<description>M = %g, Lat = %g, Lon = %g, depth = %g km</description>\n',d([4,1:3]));
fprintf(fid,'<open>1</open>\n');
for msk = 1:10
	%lw = ceil(msk/2);
	lw = 4;
	col = sprintf('%s%s%s', ...
		dec2hex(map(msk,3),2),dec2hex(map(msk,2),2),dec2hex(map(msk,1),2));
	tr0 = dec2hex(224,2);
	tr1 = dec2hex(alpha(msk),2);
	fprintf(fid,'<Style id="msk%d">\n',msk);
	fprintf(fid,'<PolyStyle><color>%s%s</color><colorMode>normal</colorMode>',tr1,col);
	fprintf(fid,'<fill>1</fill><outline>1</outline></PolyStyle>\n');
	fprintf(fid,'<LineStyle><color>%s%s</color><width>%g</width>',tr0,col,lw);
	fprintf(fid,'</LineStyle>\n');
	fprintf(fid,'</Style>\n');
end

dis = nan(10,1);
for msk = 1:10
	% computes distance of a given intensity
	f = @(x) abs(gmice(1e3*gmpe(law1,d(4),x,d(3)),law2) - msk);
	dhp = fminsearch(f,1000);	% takes 1000 km as starting distance to avoid near-field saturation (fminsearch fails)
	% only if distance is greater than depth...
	if dhp > max(d(3),1)
		dis(msk) = sqrt(dhp.^2 - d(3).^2);
		if nargout == 0
			%fprintf('I > %d @ epicentral distance = %1.0f km\n',msk,dis(msk));
			[x,y] = mkcircle(d(1),d(2),dis(msk));
			fprintf(fid,'<Placemark>\n<name>predicted intensity %s</name>\n',num2roman(msk));
			fprintf(fid,'<styleUrl>#msk%d</styleUrl>\n',msk);
			fprintf(fid,'<Polygon>\n<extrude>1</extrude>\n');
			fprintf(fid,'<altitudeMode>clampToGround</altitudeMode>\n');
			fprintf(fid,'<outerBoundaryIs>\n<LinearRing>\n<coordinates>\n');
			fprintf(fid,'%g,%g,0\n',[x,y]');
			fprintf(fid,'</coordinates>\n</LinearRing>\n</outerBoundaryIs>\n');
			fprintf(fid,'</Polygon>\n</Placemark>\n');			
		end
	end
end

if nargout > 0
	varargout{1} = dis;
end

fprintf(fid,'</Document>\n</kml>\n');
fclose(fid);
%fprintf('KML file "%s" has been created.\n',kml);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [x,y] = mkcircle(lat,lon,dis)

degkm = 6370*pi/180;

t = linspace(0,360)';
y = lat + sind(t)*dis/degkm;
x = lon + cosd(t)*dis/degkm./cosd(y);
