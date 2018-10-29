function h=pevent(t,s)
%PEVENT Plot time events.
%       PEVENT(T) adds background vertical marks on time referenced
%       plots, where:
%           T = [t] : plots lines at date and time t ;
%           T = [t1 t2] : plots areas from t1 to t2.
%
%       (c) F. Beauducel, OVSG-IPGP, 2001-06-29.

if nargin < 2
    s = .5*[1 1 1];
end

% Creates a new "axes" with same X limits
h1 = gca;
xlim = get(h1,'XLim');
axes('position',get(h1,'position'));

if size(t,2) == 1
    k = find(t>=xlim(1) & t<=xlim(2));
    hh = plot([t(k) t(k)]',[zeros(size(k)) ones(size(k))]','Color',s);
end

set(gca,'XLim',xlim,'YLim',[0 1]);
axis off
axes(h1)
set(h1,'Layer','top')

if nargout>0
    h = hh;
end
