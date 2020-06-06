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
%	Some options also available:
%	   'noframe': allows labels outside the axis limits
%	   'verbose': displays triples and azimuth values
%
%	SMARTTEXT uses function GREATCIRCLE to compute azimuth and distances.
%
%
%	Author: François Beauducel, WEBOBS/IPGP
%	Created: 2016-05-27, in Yogyakarta, Indonesia
%	Updated: 2020-06-06

hh = [];

if numel(x) ~= numel(y) || (ischar(s) && numel(x) ~= size(s,1)) || (iscell(s) && numel(x) ~= numel(s))
	error('Number of elements of X, Y and S must be consistent.')
end

k = strcmpi(varargin,'noframe');
if any(k)
	frame = false;
	varargin(k) = [];
else
	frame = true;
end

k = strcmpi(varargin,'verbose');
if any(k)
	verbose = true;
	varargin(k) = [];
else
	verbose = false;
end

if ischar(s)
	s = cellstr(s);
end

m = numel(x);
x = x(:);
y = y(:);
% adds random µm to all coordinates to avoid overlaping nodes
x = x + rand(size(x))*1e-11;
y = y + rand(size(y))*1e-11;

% adds virtual points at axis borders
if frame
	nn = 100;
	xylim = axis;
	xx = [repmat(linspace(xylim(1),xylim(2),nn),1,2),repmat(xylim(1:2),1,nn)];
	yy = [repmat(xylim(3),1,nn),repmat(xylim(4),1,nn),repmat(linspace(xylim(3),xylim(4),nn),1,2)];
	x = cat(1,x,xx(:));
	y = cat(1,y,yy(:));
end

% loops on the original size of x only
for n = 1:m
	if m==1
		az = 180;
	else
		% looks for the 2 nearest neighbors
		[~,k] = sort(greatcircle(y(n),x(n),y,x));
		if length(k) > 1
			k2 = k(2:min(3,numel(x)));
			% computes mean azimuth
			[~,~,~,bear1] = greatcircle(y(n),x(n),y(k2(1)),x(k2(1)),2);
			if length(k2) > 1
				[~,~,~,bear2] = greatcircle(y(n),x(n),y(k2(2)),x(k2(2)),2);
				az = mod((bear1(1) + bear2(1))/2 + 360,360);
				if abs(bear2(1)-bear1(1))>180
					az = az + 180;
				end
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
	
	if verbose
		fprintf('"%s": (%s / %s) az=%g - %s - %s\n',s{n},s{k2(1)},s{k2(2)},az,opt{2},opt{4});
	end
end

if nargout > 0
	varargout{1} = hh;
end

