function etatovsg(pwww)
%ETATOVSG Créer les icones d'état des stations
%       ETATOVSG(P) lit le fichier de routine "P/etats.txt" et exporte pour chaque
%       station S et capteurs xx :
%           - une icone station sous forme d'image dans "P/S.png"
%           - une icone capteur sous forme d'image dans "P/S_xx.png" (sauf pour
%             les réseaux manuels)
%           - une icone "P/S_last.png" contenant date ou heure de dernière mesure.
%
%       Note: une icone orange (au lieu de rouge) est produite dans le cas de réseaux 
%       à acquisition manuelle ou automatique si pp < 10.

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-07-01
%   Mise à jour : 2004-06-22

X = readconf;

scode = 'etats';
timelog(scode,1)
tnow = datevec(now);
today = sprintf('%4d-%02d-%02d',tnow(1:3));

fprog = X.PRGM_CONVERT;
lastblk = sprintf('%s/%s',X.RACINE_DATA_MATLAB,X.IMAGE_LAST_BLANK);
if nargin==0
    pwww = sprintf('%s/sites/etats',X.RACINE_WEB);
end

% Charge le fichier de routine
E = readetat(sprintf('%s/%s',X.RACINE_WEB,X.FILE_WEB_ETATS));

for i = 1:length(E.pp)
    s = E.ss{i};
    p = E.pp(i);
    if ~isempty(E.cc{i}), r = E.cc{i}(1); else r = ''; end
    flag = 0;
    if p >= 90
        c = 'g';
    else if p < 10
            if strcmp(r,'M')
                c = [1 .5 0];
                flag = 1;
            else
                c = 'r';
            end
        else
            c = 'y';
        end
    end
    
    if p == -1
        c = .7*[1 1 1];
        t = 'Veille';
    else
        t = sprintf('%d %%',p);
    end

    % Icone d'état général de la station ou du réseau
    if flag
        f = sprintf('%s/%03dm.png',pwww,p);
    else
        f = sprintf('%s/%03d.png',pwww,p);
    end
    if ~exist(f,'file')
        mkicone(fprog,t,c,f);
    end
    fs = sprintf('%s/%s.png',pwww,s);
    unix(sprintf('cp -f %s %s',f,fs));
    disp(sprintf('Icone:   %s mise à jour.',fs))
        
    % Icones des capteurs de station
    if length(E.cc{i})
        cn = strread(E.cc{i},'%s','delimiter',',');
    else
        cn = [];
    end
    if strcmp(s,lower(s)) & ~strcmp(r,'M') & length(cn)>1
        for ii = 1:length(cn)
            if findstr(cn{ii},'NaN')
                p = 0;
                c = 'r';
            else
                p = 100;
                c = 'g';
            end
            
            f = sprintf('%s/%03d.png',pwww,p);
            if ~exist(f,'file')
                mkicone(fprog,t,c,f);
            end
            fs = sprintf('%s/%s_%02d.png',pwww,s,ii);
            unix(sprintf('cp -f %s %s',f,fs));
            disp(sprintf('Icone:   %s mise à jour.',fs))
        end
    end

    % Icone de dernière mesure
    f = sprintf('%s/%s_last.png',pwww,s);
    if strcmp(E.dd{i},today)
        laststr = sprintf('%s %+d',E.tt{i},E.tu(i));
    else
        laststr = sprintf('%s',E.dd{i});
    end
    unix(sprintf('%s -draw ''text 10,15 "%s"'' -font fixed %s %s',fprog,laststr,lastblk,f));
    unix(sprintf('/bin/touch %s',f));
    
    disp(sprintf('Icone:   %s créée.',f))
end

% Icone de mise à jour OVSG
f = sprintf('%s/MAJOVSG_last.png',pwww);
unix(sprintf('%s -draw ''text 15,15 "%s"'' -font fixed %s %s',fprog,today,lastblk,f));
unix(sprintf('/bin/touch %s',f));
disp(sprintf('Icone:   %s créée.',f))

timelog(scode,2)

