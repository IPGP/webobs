function pos=getouterbox(fig)
%GETOUTERBOX Get position of outerbox figure.
%
if nargin < 1
	fig = gcf;
end
h = get(fig,'Children');
pos = [1,1,0,0];
for a = h(:)'
	p = plotboxpos(a);
	pos(1) = min(pos(1),p(1));
	pos(2) = min(pos(2),p(2));
	pos(3) = max(pos(3) + pos(1),p(3) + p(1)) - pos(1);
	pos(4) = max(pos(4) + pos(2),p(4) + p(2)) - pos(2);
end
