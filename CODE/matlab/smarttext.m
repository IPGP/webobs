function varargout=smarttext(x,y,s,varargin)
%SMARTTEXT Optimized text labelling
%	SMARTTEXT(LON,LAT,S) adds the text string S to (LON,LAT) location, as 
%	the function TEXT does in 2-D. If LON and LAT are vectors and S an 
%	array of strings, SMARTTEXT will optimize the text position and alignment, 
%	trying to minimize text overlapping. LON and LAT must be in degree.
%
%	SMARTTEXT(...,param1,value1,param2,value2,...) specifies additionnal 
%	properties of the text using parameter/value pairs. See TEXT 
%	documentation for further information.
%
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2016-05-27, in Yogyakarta, Indonesia
%	Updated: 2019-05-29

hh = [];

if numel(x) ~= numel(y) || (ischar(s) && numel(x) ~= size(s,1)) || (iscell(s) && numel(x) ~= numel(s))
	error('Number of elements of X, Y and S must be consistent.')
end

if ischar(s)
	s = cellstr(s);
end

m = numel(x);
% adds random µm to all latitudes to avoid overlaping nodes
y = y + rand(size(y))*1e-11;

for n = 1:m
	if m==1
		az = 180;
	else
		% looks for the 2 nearest neighbors
		[~,k] = sort(greatcircle(y(n),x(n),y,x));
		k2 = k(2:min(3,m));
		% computes mean azimuth
		[~,~,~,bear] = greatcircle(mean(y(k2)),mean(x(k2)),y(n),x(n),2);
		az = mod(bear(1) + 360,360);
	end

	switch 45*round(az/45)
	case {0,360} % north
		opt = {'VerticalAlignment','middle','HorizontalAlignment','center'};
		ss = {s{n},'',''};
	case 45 % northeast
		opt = {'VerticalAlignment','middle','HorizontalAlignment','left'};
		ss = {[s{n},' '],'',''};
	case 90 % east
		opt = {'VerticalAlignment','middle','HorizontalAlignment','left'};
		ss = ['   ',s{n}];
	case 135 % southeast
		opt = {'VerticalAlignment','middle','HorizontalAlignment','left'};
		ss = {'','',[' ',s{n}]};
	case 180 % south
		opt = {'VerticalAlignment','middle','HorizontalAlignment','center'};
		ss = {'','',s{n}};
	case 225 % southwest
		opt = {'VerticalAlignment','middle','HorizontalAlignment','right'};
		ss = {'','',[' ',s{n}]};
	case 270 % west
		opt = {'VerticalAlignment','middle','HorizontalAlignment','right'};
		ss = [s{n},'   '];
	case 315 % northwest
		opt = {'VerticalAlignment','middle','HorizontalAlignment','right'};
		ss = {[s{n},' '],'',''};
	otherwise
		opt = [];
		ss = s{n};
	end


	h = text(x(n),y(n),ss,opt{:},varargin{:});
	hh = cat(1,hh,h);
end

if nargout > 0
	varargout{1} = hh;
end

