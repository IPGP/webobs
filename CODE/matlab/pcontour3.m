function h=pcontour3(c,z,varargin)
%PCONTOUR3 Plot contour in 3D.
%	PCONTOUR3(C,Z) or PCONTOUR3(C,Z,S) plots contour matrix C (result of
%	CONTOURC function) in plane Z, in gray lines or with line style S.
%
%  	The contour matrix C is a two row matrix of contour lines. Each
% 	contiguous drawing segment contains the value of the contour,
% 	the number of (x,y) drawing pairs, and the pairs themselves.
% 	The segments are appended end-to-end as
%
%  	    C = [level1 x1 x2 x3 ... level2 x2 x2 x3 ...;
%  	         pairs1 y1 y2 y3 ... pairs2 y2 y2 y3 ...]
%

%	Author: François Beauducel <beauducel@ipgp.fr>
%	Created: 2021-01-16 in Yogyakarta, Indonesia
%	Updated: 2021-01-16

% Test the number of lines, index into c and level
hh = [];
n = [];
if ~isempty(c)
	i = 1;
	while i > 0
		n = cat(1,n,[i+1 i+c(2,i) c(1,i)]);
		i = i + c(2,i) + 1;
		if i > length(c)
			i = -1;
		end
	end

	if ~isempty(get(gcf,'Children'))
		axis(axis)
	end
	hd = ishold;
	hold on
	[~,j] = sort(n(:,3));
	j = flipud(j);
	for i = 1:size(n,1)
    		k = n(j(i),1):n(j(i),2);
 		hh = cat(2,hh,plot3(c(1,k),c(2,k),z*ones(1,length(k)),varargin{:}));
	end
	if ~hd
		hold off
	end
end
if nargout
	h = hh;
end
