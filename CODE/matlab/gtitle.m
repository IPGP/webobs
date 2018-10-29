function to=gtitle(s,ext)
%GTITLE Returns extented title for graphs
%	GTITLE(S,EXT) returns a TeX string with S in bold and timescale information. 
%
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2002, in Guadeloupe, F.W.I.
%   Updated: 2017-09-04

nt = '';
if nargin > 1 && ~isempty(ext)
	nt = sprintf(' (%s)',timescales(ext));
end
tt = sprintf('{\\bf%s}%s',s,nt);
if nargout == 0
	title(tt,'FontSize',14)
else
	to = {sprintf('{\\fontsize{14} %s} ',tt)};
end
