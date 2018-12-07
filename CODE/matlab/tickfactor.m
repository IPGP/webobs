function tickfactor(f,a)
%TICKFACTOR Rescaling X/Y ticks by a factor
%	TICKFACTOR(F) rescales existing ticks of current axes by a factor of F.
%
%	TICKFACTOR(F,A) rescales only axis A as 'X' or 'Y'.
%
%	Author: François Beauducel, IPGP/WEBOBS
%	Created: 2018-12-07 in Yogyakarta (Indonesia)

xt = get(gca,'XTick');
xtl = get(gca,'XTickLabel');
yt = get(gca,'YTick');
ytl = get(gca,'YTickLabel');

if ~isempty(xt) && ~isempty(xtl) && (nargin < 2 || strcmpi(a,'x'))
	set(gca,'XTick',xt,'XTickLabel',strtrim(cellstr(num2str(xt'*f))))
end

if ~isempty(yt) && ~isempty(ytl) && (nargin < 2 || strcmpi(a,'y'))
	set(gca,'YTick',yt,'YTickLabel',strtrim(cellstr(num2str(yt'*f))))
end
