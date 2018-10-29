function mkxhyp(f,G,dhyp)
%MKXHYP Exports hypo file
%   MKXHYP(F,DIRSPEC,DHYP)
%
%   Author: F. Beauducel, IPGP
%   Created: 2009-10-08
%   Modified: 2009-10-09

X = readconf;

if isfield(G,'dsp')
	dirspec = G.dsp;
end
if findstr(f,'_xxx')
	ftxt = sprintf('%s/%s/%s.txt',X.RACINE_WEB,dirspec,f);
else
	ftxt = sprintf('%s/%s/%s.txt',X.RACINE_FTP,G.ftp,f);
end

fid = fopen(ftxt,'wt');
fprintf(fid,'%s\n',dhyp{:});
fclose(fid);

disp(sprintf('File: %s exported.',ftxt));

