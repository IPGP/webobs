function ovsg(x)
%OVSG   Routines des réseaux OVSG
%       OVSG sans argument lance l'ensemble des routines de réseaux pour création
%       des graphes courants et de l'état des réseaux (routine automatique).
%
%       OVSG('all') lance uniquement les graphes de toutes les données.
%
%       Particularités:
%           - les scripts de traitement sont lancés avec la fonction EVAL, ce qui permet
%             de poursuivre la routine en cas d'erreur sur l'un des scripts.
%           - les deux fichiers d'état (stations et PC) sont mergés en fin de routines
%             pour produire le fichier d'état unique utilisé pour la feuille de routine.
%           - tous les lundis à 6h, un mail est envoyé à ovsg@ovsg.univ-ag.fr pour dresser
%             un bilan des pannes.

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-06-06
%   Mise à jour : 2007-02-15

X = readconf;
R = readgr;

url = sprintf('http://%s/sites/etats/feuille_routine.htm',X.RACINE_URL);
pftp = sprintf('%s/Reseaux/Etats',X.RACINE_FTP);
pwww = sprintf('%s/sites/etats',X.RACINE_WEB);
fwww = [pwww '/etats.txt'];
fwhs = [pwww '/etats_hs.htm'];
f1 = sprintf('%s/data/etats.dat',X.RACINE_OUTPUT_MATLAB);
f2 = sprintf('%s/data/etats_st.dat',X.RACINE_OUTPUT_MATLAB);
f3 = sprintf('%s/data/etats_pc.dat',X.RACINE_OUTPUT_MATLAB);
tnow = datevec(now);
snow = sprintf('%4d-%02d-%02d %02d:%02d:%02.0f',tnow);
snow0 = sprintf('%4d-%02d-%02d %02d:%02d:%02.0f',datevec(now + 4/24));

% Pas d'argument 
if nargin < 1
    fid = fopen(f1,'wt');
    fprintf(fid,'#--------------------------------------------------------\n');
    fprintf(fid,'# ROUTINE OVSG: état automatique des stations\n');
    fprintf(fid,'# %s (locales)\n#\n',datestr(now));
    fprintf(fid,'#Pb  Station   E%%  A%% Date       Heure    TU Dernières données \n');
    fprintf(fid,'#------------|---|---|----------|--------|--|------------------\n');
    fprintf(fid,'-     ROUTINE 100 100 %s -4 1\n',snow);

    % Etat en veille des stations invalides des réseaux d'acquisition
    %ST = readst('','G',0);
    %k = find(ST.ope == 0);
    %for i = 1:length(k)
    %    fprintf(fid,'-     %7s  -1  -1 %s -4\n',lower(ST.cod{k(i)}),snow);
    %end
	
    % Réseaux non traités (sauf type Information)
    %rnt = {'GPSREP','NIVEL','RADON','EAUX','GRAVI','RADIO','FREEWAVE','BATIM','VEHICULES'};
    %for i = 1:length(rnt)
    %    k = find(strcmp(cellstr(char(R.rcd)),rnt(i)));
    %    ST = readst(R(k).cod,R(k).obs);
    %		if ~strcmp(R(k).typ,'I')
    %        for ii = 1:length(ST.cod)
    %            if ST.ope(ii)
    %                fprintf(fid,'-     %7s 100 100 0000-00-00 00:00:00 -4\n',lower(ST.cod{ii}));
    %			    else
    %                fprintf(fid,'-     %7s  -1  -1 0000-00-00 00:00:00 -4\n',lower(ST.cod{ii}));
    %            end
    %end
    %        fprintf(fid,'-     %7s 100 100 %s -4 %d %ss\n',R(k).rcd,snow,length(ST.cod),R(k).snm);
    %    end
    %end        
    %for i = 1:length(s0)
    %    if s0{i}(1) ~= '-'
    %        fprintf(fid,'%s\n',s0{i});
    %    else
    %        fprintf(fid,'%s %s %s\n',s0{i}(1:21),snow,s0{i}(43:end));
    %    end
    %end
    fclose(fid);
    
    % Routines "horaires"
%    eval('sismohyp','disperr(''sismohyp'')');
%    eval('saintes','disperr(''saintes'')');
%    eval('sismocp','disperr(''sismocp'')');
%    eval('sismolb','disperr(''sismolb'')');
%    eval('ew','disperr(''ew'')');
%    eval('rap','disperr(''rap'')');
%    eval('rsam','disperr(''rsam'')');
%    eval('sismobul','disperr(''sismobul'')');
%    eval('inclino','disperr(''inclino'')');
%    eval('gpscont','disperr(''gpscont'')');
%    eval('tempflux','disperr(''tempflux'')');
%    eval('tides','disperr(''tides'')');
%    eval('aemd','disperr(''aemd'')');
%    eval('extenso','disperr(''extenso'')');
%    eval('fissuro','disperr(''fissuro'')');
%    eval('gaz','disperr(''gaz'')');
%    eval('bojap','disperr(''bojap'')');
%    eval('sources','disperr(''sources'')');
%    %eval('pselec','disperr(''pselec'')');
%    %eval('magn','disperr(''magn'')');
%    eval('meteo','disperr(''meteo'')');
%    eval('pluvio','disperr(''pluvio'')');
%    eval('cameras','disperr(''cameras'')');
%    eval('stations','disperr(''stations'')');
%    %eval('mkweb','disperr(''mkweb'')');
%    %eval('acqui','disperr(''acqui'')');

    % Copie des fichiers d'états stations + PC => "etats.txt"
    unix(sprintf('cp -fpu %s %s',f1,f2));
    unix(sprintf('cat %s %s > %s',f2,f3,fwww));

    % Fabrication de la feuille de routine
    %eval('routine','disperr(''routine'')');
    
    % Mise à jour de l'état des stations
    %etatovsg(pwww)

    %if ~isempty(lasterr)
    %    unix('mail postmaster -s ''Matlab ERROR: ovsgpost.m'' < ovsg.log')
    %end

    % Envoi de la routine (tous les lundis à 06h)
    if tnow(4) == 6 & tnow(5) < 30 & strcmp(datestr(datenum(tnow),'ddd'),'Mon')
        [s,w] = unix(sprintf('grep -iw "X" %s',fwww));
        if ~isempty(w)
            c = strread(w,'%s','delimiter','\n');
        else
            c = '';
        end
        fid = fopen(fwhs,'wt');
        fprintf(fid,'<html>');
        fprintf(fid,'<b>%s : %d</b> station(s) en panne ou données pas à jour<br>',datestr(now),length(c));
        fprintf(fid,'<blockquote><pre><font face=Courier size=0>');
        for i = 1:length(c)
            fprintf(fid,'%s\n',c{i}(1:44));
        end
        fprintf(fid,'</font></pre></blockquote>Détails sur la <a href=%s>Feuille de routine</a><br>',url);
        fprintf(fid,'</html>');
        fclose(fid);
        unix(sprintf('mail probleme@soufriere -s ''Bilan pannes réseau OVSG'' < %s',fwhs));
    end
    
    % Statistiques accès Web
    %eval('webstat(1)','disperr(''webstat'')');
	
	
	% met à jour un lien symbolique sur le dernier bulletin de l'OVSG
	pftp = 'Publis/Bilans';
	flst = sprintf('%s/%s/lastbulletin.pdf',X.RACINE_FTP,pftp);
	fjpg = sprintf('%s/%s/lastbulletin.jpg',X.RACINE_FTP,pftp);
	[w,s] = unix(sprintf('find %s/%s/ -name OVSG_*.pdf',X.RACINE_FTP,pftp));
	f = strread(s,'%s','delimiter','\n');
	if ~isempty(f)
		% pour éviter les erreurs liées à l'inexistance des fichiers...
		if ~exist(flst,'file'), unix(sprintf('touch %s',flst)); end
		% calcul des dates des fichiers
		D0 = dir(f{end});
		D1 = dir(flst);
		if ~strcmp(D0.date,D1.date)
			ff = strread(f{end},'%s','delimiter','/');
			unix(sprintf('ln -s -f %s/%s %s',ff{end-1},ff{end},flst));
			unix(sprintf('%s -scale 71x100 %s %s',X.PRGM_CONVERT,flst,fjpg));
		end
	end
    
else
    
%     % Routines "journalières"
%     eval('rsam(1,''all'')','disperr(''rsam'')');
%     eval('sismobul(1,''all'')','disperr(''sismobul'')');
%     eval('sismohyp(1,''all'')','disperr(''sismohyp'')');
%     eval('sismoecole','disperr(''sismoecole'')');
%     eval('inclino(1,''all'')','disperr(''inclino'')');
%     eval('gpscont(1,''all'')','disperr(''gpscont'')');
%     eval('tempflux(1,''all'')','disperr(''tempflux'')');
%     eval('tides(1,''all'')','disperr(''tides'')');
%     eval('aemd(1,''all'')','disperr(''aemd'')');
%     eval('extenso(1,''all'')','disperr(''extenso'')');
%     eval('fissuro(1,''all'')','disperr(''fissuro'')');
%     eval('gaz(1,''all'')','disperr(''gaz'')');
%     eval('bojap(1,''all'')','disperr(''bojap'')');
%     eval('sources(1,''all'')','disperr(''sources'')');
%     %eval('pselec(1,''all'')','disperr(''pselec'')');
%     %eval('magn(1,''all'')','disperr(''magn'')');
%     eval('meteo(1,''all'')','disperr(''meteo'')');
%     eval('pluvio(1,''all'')','disperr(''pluvio'')');
%     eval('mapnet','disperr(''mapnet'')');
%     eval('mkpostat','disperr(''mkpostat'')');
%     %eval('webstat','disperr(''webstat'')');
    
end

% Affiche des informations sur l'erreur
function disperr(s)
disp(sprintf('* %s Matlab Error: Problème avec la fonction %s',datestr(now),upper(s)));
disp(sprintf('  "%s"',lasterr));
