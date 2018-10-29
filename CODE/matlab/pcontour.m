function h = pcontour(c,s,m,lim)
%PCONTOUR Plot contour.
%	PCONTOUR(C) or PCONTOUR(C,S) plots contour matrix C (result of 
%	CONTOURC function), in gray lines or with line style S.
%
%	PCONTOUR(C,S,MAP) fills the contours with colormap MAP, like the 
%	Matlab 5 CONTOURF function.
%
%	PCONTOUR(C,S,MAP,LIM) fills contours using FILLOUT function with
%	 LIM outer limit box.
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

%	Author: François Beauducel <beauducel@ipgp.fr>
%	Created: 1998, in Naples, Italy
%	Updated: 2016-05-25

if nargin < 2
	s = .8*[1 1 1];
end
flag = 0;
if nargin == 4
	flag = 1;
end
	

% Test the number of lines, index into c and level
n = [];
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
hh = [];
for i = 1:size(n,1)
    k = n(j(i),1):n(j(i),2);
    if nargin < 3
        hh = cat(2,hh,plot(c(1,k),c(2,k),'Color',s));
    else
        maxsc = diff(minmax(n(:,3)));
        if size(m,1)>1 && maxsc ~= 0
            cl = m(round((length(m)-1)*(n(j(i),3)-min(n(:,3)))/maxsc)+1,:);
        else cl = m(1,:);
        end
		if flag
			hh = cat(2,hh,fillout(c(1,k),c(2,k),lim,cl));
		else
			hh = cat(2,hh,fill(c(1,k),c(2,k),cl));
		end
    end
end
if ~hd
	hold off
end
if nargout
	h = hh;
end
