function s = varsub(s,V,opt)
%VARSUB Variable substitution in string s using keys of structure V
%	VARSUB(STR,V) returns string STR after substition of any variable $xxx or ${xxx}
%	that matches fieldname in structure V.
%	Example:
%		V.report_date = datestr(now);
%		varsub('Report on ${report_date}',V)
%
%	VARSUB(STR,V,'tex') also subtitutes any unicode character to TeX markup.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2017-01-25, in Yogyakarta, Indonesia
%	Updated: 2019-02-16

for k = fieldnames(V)'
	% keeps escaped underscores
	if ~isempty(strfind(V.(k{:}),'\_'))
		V.(k{:}) = strrep(V.(k{:}),'\_','\\_');
	end
	s = regexprep(s,['\$',k{:},'\>'],V.(k{:}));	% $keyword (must be word isolated)
	s = regexprep(s,['\${',k{:},'}'],V.(k{:}));	% ${keyword}
end

if nargin > 2 && strcmpi(opt,'tex')
	s = regexprep(s,'é','\\''e');
	s = regexprep(s,'è','\\`e');
	s = regexprep(s,'ê','\\^e');
	s = regexprep(s,'ë','\\^e');
	s = regexprep(s,'à','\\`a');
	s = regexprep(s,'â','\\^a');
end
