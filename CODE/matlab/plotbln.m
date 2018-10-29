function h = plotbln(c,s,l,r)
%PLOTBLN Plot contour BLN.
%	PLOTBLN(C) or PLOTBLN(C,S) plots contour matrix C (result of 
%	CONTOURC function), in gray lines or with line style S.
%
%	PLOTBLN uses level values to determine line width, and 
%	PLOTBLN(C,S,LEVELS,RATIO) plots only levels in LEVELS vector,
%	and optionaly multiplies line width by RATIO.
%
%  	The contour matrix C is a two row matrix of contour lines. Each
% 	contiguous drawing segment contains the value of the contour, 
% 	the number of (x,y) drawing pairs, and the pairs themselves.  
% 	The segments are appended end-to-end as
%  
%  	    C = [level1 x1 x2 x3 ... level2 x2 x2 x3 ...;
%  	         pairs1 y1 y2 y3 ... pairs2 y2 y2 y3 ...]
%
%	See also EBLN and IBLN.

%	Author: F. Beauducel, OVSG-IPGP
%	Created: 2004
%	Updated: 2014-12-01

if nargin < 2
	s = .8*[1 1 1];
end
if nargin < 3
	l = [];
end
if nargin < 4
	r = 1;
end

% Test the number of lines, index into c and level
n = [];
i = 1;
while i > 0
	n = [n;[i+1 i+c(2,i) c(1,i)]];
	i = i + c(2,i) + 1;
	if i > length(c), i = -1; end
end

if ~isempty(get(gcf,'Children')) axis(axis), end

hd = ishold;
hold on
[k,j] = sort(n(:,3));
j = flipud(j);
hh = [];
for i = 1:size(n,1)
	k = n(j(i),1):n(j(i),2);
	if isempty(l) | length(find(l == n(j(i),3)))
		hh = [hh;plot(c(1,k),c(2,k),'Color',s,'LineWidth',r*n(j(i),3))];
	end
end

if ~hd, hold off, end
if nargout, h = hh; end
