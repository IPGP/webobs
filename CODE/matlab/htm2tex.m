function s=htm2tex(s);
%HTM2TEX HTML to TEX text conversion.
%
%	Author: Francois Beauducel <beauducel@ipgp.fr>
%	Created: 2016-08-12, in Paris (France)

% ---- special characters (to ISO)
s = regexprep(s,'&eacute;','é');
s = regexprep(s,'&Eacute;','É');
s = regexprep(s,'&egrave;','è');
s = regexprep(s,'&Egrave;','È');
s = regexprep(s,'&ecirc;','ê');
s = regexprep(s,'&Ecirc;','Ê');
s = regexprep(s,'&agrave;','à');
s = regexprep(s,'&Agrave;','À');
s = regexprep(s,'&ugrave;','ù');
s = regexprep(s,'&Ugrave;','Ù');
s = regexprep(s,'&ccedil;','ç');
s = regexprep(s,'&Ccedil;','Ç');
s = regexprep(s,'&icirc;','î');
s = regexprep(s,'&Icirc;','Î');

% ---- html tags
% subscript
s = regexprep(s,'<sub>(.?)</sub>','_{$1}','ignorecase');
% superscript
s = regexprep(s,'<sup>(.?)</sup>','^{$1}','ignorecase');
% bold
s = regexprep(s,'<b>(.?)</b>','\bf{$1}','ignorecase');
% italic
s = regexprep(s,'<i>(.?)</i>','\it{$1}','ignorecase');
% cleans any other html tags
s = regexprep(s,'<.?>','');
