function h=pevent(t,s)
%PEVENT Trace des marques verticales.
%       PEVENT(T) ajoute des lignes verticales entre 1 et 2 (échelle 
%       logarithmique), à chaque valeur de temps du vecteur T.
%
%       (c) F. Beauducel, 2001-07-26, OVSG.

if nargin < 2
    s = .5*[1 1 1];
end

v = axis;
k = find(t>=v(1) & t<=v(2));

hold on
if size(t,2) == 1
    hh = semilogy([t(k) t(k)]',[1.5*ones(size(k)) 3*ones(size(k))]', 'Color',s);
end
hold off

if nargout>0
    h = hh;
end
