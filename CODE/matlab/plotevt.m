function varargout=plotevt(x,varargin)
%PLOTEVT Display time referenced events.
%	PLOTEVT(X) plots vertical line in the background of all axes in the 
%	current figure, at abscissa X (scalar or vector).
%
%	PLOTEVT(X,param,value,...) adds any valid plot param/value pairs to set
%	line style and color.
%
%
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2014-03-29
%   Updated: 2017-07-22


% Detects all axes in the current figure
ha = findobj(gcf,'Type','axes');

% save current axes
gca_save = gca;

for i = 1:length(ha)
	axes(ha(i));
	xlim = get(ha(i),'XLim');
	k = find(x <= xlim(2) & x >= xlim(1));
	if ~isempty(k)
		ylim = get(ha(i),'YLim');
		if strcmp(get(ha(i),'YScale'),'log')
			ddy = 0;
		else
			ddy = diff(ylim)*0.005;
		end
		h = zeros(size(k));
		for ii = 1:length(k)
			x1 = x(k(ii));
			y1 = ylim(1) + ddy;
			y2 = ylim(2) - ddy;
			hold on
			h(ii) = plot([x1,x1],[y1,y2],varargin{:});
			hold off
		end
		set(ha(i),'YLim',ylim);
		% puts all in the background
		hc = get(ha(i),'Children');
		if length(hc) > length(h)
			set(ha(i),'Children',hc([(length(h)+1):length(hc),1:length(h)]));
		end
	end
end

% reset current axes
axes(gca_save);

if exist('h','var')
	hh = h;
else
	hh = [];
end

if nargout > 0
	varargout{1} = hh;
end
