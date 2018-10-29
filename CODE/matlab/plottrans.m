function h=plottrans(WO,N,s,varargin)
%PLOTTRANS Plot transmission
%   PLOTTRANS(WO,N,MARKERSIZE) plots transmission paths and repeater positions
%   relative to the node N (structure from readnode) on current figure, using optional
%   marker size MARKERSIZE (in points).
%
%   PLOTTRANS(WO,N,SIZE,'utm') 
%
%
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2014-08-17, in Yogyakarta, Indonesia
%   Updated: 2017-08-02


NODES = readcfg(WO,WO.CONF_NODES); % loads nodes config.
T = readcfg(WO,NODES.FILE_TELE);

if ~isfield(N,'TRANSMISSION') | ~isstruct(N.TRANSMISSION) | ~isfield(N.TRANSMISSION,'NODES') | N.TRANSMISSION.TYPE < 1
	h = [];
	return
end

if nargin < 3 || ~isnumeric(s) || s <= 0
	s = 7;
end


x = N.LON_WGS84;
y = N.LAT_WGS84;
for n = 1:length(N.TRANSMISSION.NODES)
	r = sprintf('REPEATER%d',n);
	x = [x;str2num(N.TRANSMISSION.(r).LON_WGS84)];
	y = [y;str2num(N.TRANSMISSION.(r).LAT_WGS84)];
end

t = sprintf('KEY%d',N.TRANSMISSION.TYPE);
if any(strcmpi(varargin,'utm'))
	[x,y] = ll2utm(y,x);
	h1 = plot(x,y,'LineStyle',T.(t).style,'LineWidth',str2num(T.(t).width),'Color',str2num(T.(t).rgb));
else
	for n = 2:length(x)
		[lat,lon] = greatcircle(y(n-1),x(n-1),y(n),x(n),10);
		h1 = plot(lon,lat,'LineStyle',T.(t).style,'LineWidth',str2num(T.(t).width),'Color',str2num(T.(t).rgb));
	end
end

h2 = plot(x(2:end),y(2:end),'p','MarkerFaceColor','w','MarkerEdgeColor','k','MarkerSize',s);

h = [h1,h2];
