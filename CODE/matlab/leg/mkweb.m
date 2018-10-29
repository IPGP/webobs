function mkweb(p)
%MKWEB Fabrique les pages Web
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-07-12
%   Mise à jour : 2005-10-19

rcode = 'MKWEB';
timelog(rcode,1)

today = now;

X = readconf;
novsg = textread(sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.FILE_NOTES_OVSG),'%s','delimiter','\n');
tovsg = textread(sprintf('%s/ACCUEIL_titre.txt',X.RACINE_DATA_WEB),'%s','delimiter','\n');
iovsg = textread(sprintf('%s/ACCUEIL_informations.txt',X.RACINE_DATA_WEB),'%s','delimiter','\n');
tactu = textread(sprintf('%s/ACCUEIL_actu.txt',X.RACINE_DATA_WEB),'%s','delimiter','\n');
css = sprintf('<LINK rel="stylesheet" type="text/css" href="/%s">',X.FILE_CSS);
U = readus;
H = loadhebdo;

% Page d'accueil
f = sprintf('%s/accueil.htm',X.RACINE_WEB);
fid = fopen(f,'wt');
fprintf(fid,'<HTML><HEAD><TITLE>Accueil OVSG - %s</TITLE>%s</HEAD>\n',datestr(now),css);
fprintf(fid,'<BODY><FORM>\n');
for i = 1:length(tovsg)
    fprintf(fid,'%s\n',tovsg{i});
end
fprintf(fid,'<TABLE width="100%%"><TR><TD width="330" rowspan="2" valign="top" align="center">');
for i = 1:length(tactu)
    fprintf(fid,'%s\n',tactu{i});
end
fprintf(fid,'</TD><TD valign="top">');
for i = 1:length(iovsg)
    fprintf(fid,'%s\n',iovsg{i});
end
fprintf(fid,'</TD></TR>\n');
fprintf(fid,'<TR><TD valign="top" bgcolor="#EEEEEE"><H2>Actualités du %s %s %s %s</H2><BLOCKQUOTE>\n',traduc(datestr(today,'ddd')),datestr(today,'dd'),traduc(datestr(today,'mmm')),datestr(today,'yyyy'));
for i = 1:length(H.chp{1})
    k = find(strcmp(H.chp{1}(i),H.typ));
    if ~isempty(k)
        fprintf(fid,'<H3>%s</H3><UL type="square">\n',H.chp{2}{i});
        for ii = 1:length(k)
            if H.dt1(k(ii)) ~= H.dt2(k(ii))
                dte = sprintf('du %s au %s',datestr(H.dt1(k(ii))),datestr(H.dt2(k(ii))));
            else
                dte = '';
            end
            if H.dt1(k(ii)) ~= floor(H.dt1(k(ii)))
                hrs = sprintf('<I>%s</I> -',datestr(H.dt1(k(ii)),'HH:MM'));
            else
                hrs = '';
            end
            lieu = sprintf('<I>%s</I>',H.lieu{k(ii)});
            kk = find(strcmp(H.obs{k(ii)},U.cod));
            if ~isempty(kk)
                obs = U.nom{kk};
            else
                obs = H.obs{k(ii)};
            end
            if ~isempty(H.col{k(ii)})
                qui = sprintf('%s + %s',obs,H.col{k(ii)});
            else
                qui = sprintf('%s',obs);
            end
            
            switch H.chp{1}{i}
            case {'Absence','Astreinte'}
                fprintf(fid,'<LI><B>%s - %s :</B> %s %s\n',obs, lieu, H.obj{k(ii)},dte);
            case 'Stage'
                fprintf(fid,'<LI><B>%s :</B> %s. Stage %s (resp: %s)\n',H.col{k(ii)}, H.obj{k(ii)},dte,obs);
            case 'Mission'
                fprintf(fid,'<LI><B>%s :</B> %s %s\n',H.col{k(ii)}, H.obj{k(ii)},dte);
            otherwise    
                fprintf(fid,'<LI><B>%s %s :</B> %s (%s)\n',hrs,lieu,H.obj{k(ii)},qui);
            end    
        end
        fprintf(fid,'</UL>');
    end
end

fprintf(fid,'</BLOCKQUOTE><P>Et aussi <A href="/actu/">le reste de l''actualité et les archives</A>.</P>');
fprintf(fid,'</TD><TR></TABLE><HR><H6>');
for i = 1:length(novsg)
    fprintf(fid,'%s\n',novsg{i});
end
fprintf(fid,'<BR>Mise à jour: %s</H6>',datestr(now));
fprintf(fid,'</FORM></BODY></HTML>\n');
fclose(fid);
disp(sprintf('Page: %s créée.',f))

timelog(rcode,2)
