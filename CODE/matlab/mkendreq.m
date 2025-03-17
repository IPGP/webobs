function mkendreq(WO,P)
%MKENDREQ Makes post-request jobs
%	MKENDREQ(WO,P) uses the PROC's structure P to:
%	- make a .tgz archive
%	- send a message with links to results
%
%
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2014-07-12
%   Updated: 2025-03-13


wofun = sprintf('WEBOBS{%s}',mfilename);

% makes a .tgz archive of in the upper directory of OUTDIR
ptgz = P.GTABLE.OUTDIR;
preq = regexprep(ptgz,'/[^/]*$','');
freq = regexprep(ptgz,'/.*/([^/]*)$','$1');
ftgz = [ptgz, '.tgz'];
fprintf('%s: creating archive %s ... ',wofun,ftgz);

wosystem(sprintf('mkdir -p %s',ptgz));
wosystem(sprintf('tar zcf %s -C %s %s',ftgz,preq,freq));
fprintf('done.\n');

grid = P.GTABLE.SELFREF;

% request directory
reqdir = regexprep(regexprep(P.GTABLE.OUTDIR,sprintf('%s/',WO.ROOT_OUTR),''),sprintf('/%s',grid),'');

% root URL
url = field2str(P.GTABLE,'ORIGIN',field2str(WO,'ROOT_URL','http://webobs','notempty'),'notempty');

% makes a comprehensive text message for email notification
f = sprintf('%s/mail.txt',P.GTABLE.OUTDIR);
fid = fopen(f,'wt');
fprintf(fid,'\n\nDate: %s\n',datestr(now));
fprintf(fid,'GRID: {%s} %s (%d nodes)\n',grid,P.NAME,length(P.NODESLIST));
fprintf(fid,'Time period: from %s to %s\n',datestr(P.GTABLE.DATE1),datestr(P.GTABLE.DATE2));
fprintf(fid,'\nFollow this link to access your results:\n\n');
fprintf(fid,'%s?page=/cgi-bin/showOUTR.pl?dir=%s&grid=%s\n',url,reqdir,grid);
fprintf(fid,'\nor download all files in a single archive:\n\n');
fprintf(fid,'%s%s\n',url,regexprep(ftgz,WO.ROOT_SITE,''));
fclose(fid);

notify(WO,'formreq.','!',sprintf('uid=%s file=%s',P.GTABLE.UID,f));

