function varargout=smarttext(x,y,s,varargin)
%SMARTTEXT Optimized text labelling in lat/lon
%	SMARTTEXT(LON,LAT,S) adds the text string S to (LON,LAT) location, as 
%	the function TEXT does in 2-D. If LON and LAT are vectors and S an 
%	array of strings, SMARTTEXT will optimize the text position and alignment, 
%	trying to minimize text overlapping. LON and LAT must be in degree.
%
%	SMARTTEXT(...,param1,value1,param2,value2,...) specifies additionnal 
%	properties of the text using parameter/value pairs. See TEXT 
%	documentation for further information.
%
%	SMARTTEXT uses function GREATCIRCLE to compute azimuth and distances.
%
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2016-05-27, in Yogyakarta, Indonesia
%	Updated: 2019-12-23

hh = [];

if numel(x) ~= numel(y) || (ischar(s) && numel(x) ~= size(s,1)) || (iscell(s) && numel(x) ~= numel(s))
	error('Number of elements of X, Y and S must be consistent.')
end

if ischar(s)
	s = cellstr(s);
end

m = numel(x);
% adds random µm to all coordinates to avoid overlaping nodes
x = x + rand(size(x))*1e-11;
y = y + rand(size(y))*1e-11;

for n = 1:m
	if m==1
		az = 180;
	else
		% looks for the 2 nearest neighbors
		[~,k] = sort(greatcircle(y(n),x(n),y,x));
		if length(k) > 1
			k2 = k(2:min(3,m));
			% computes mean azimuth
			[~,~,~,bear1] = greatcircle(y(n),x(n),y(k2(1)),x(k2(1)),2);
			if length(k2) > 1
				[~,~,~,bear2] = greatcircle(y(n),x(n),y(k2(2)),x(k2(2)),2);
				az = mod((bear1(1) + bear2(1))/2 + 360,360);
			else
				az = bear1(1);
			end
		end
	end

	switch mod(45*round((az+180)/45),360)
	case 0  % north
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
		opt = {};
		ss = s{n};
	end

	h = text(x(n),y(n),ss,opt{:},varargin{:});
	hh = cat(1,hh,h);
end

if nargout > 0
	varargout{1} = hh;
end

