function acqui(pwww)
%ACQUI Test des acquisitions OVSG
%       ACQUI effectue les opérations suivantes:
%           - interprète le fichier d'état des acquisitions réalisé par le script
%             "test-etat-info.ksh" et construit un fichier "etats_pc.txt" synthétisant
%             l'état des machines d'acquisition;
%           - merge les 2 fichiers "etats_st.txt" et "etats_pc.txt".
%
%       Spécificités du traitement:
%           - cette routine est indépendante des traitements graphiques "ovsg.m" et
%             peut donc etre lancée à n'importe quel moment;
%           - pour sismodep1 et sismodep2 : l'état de acqsismo1 et acqsismo2 est 
%             déterminé en fonction.

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2001-10-09
%   Mise à jour : 2004-12-17

X = readconf;
rname = 'acqui';
timelog(rname,1)

% Initialisation des variables
if nargin == 0
    fwww = sprintf('%s/%s',X.RACINE_WEB,X.FILE_WEB_ETATS);
end
f1 = sprintf('%s/data/etats_st.dat',X.RACINE_OUTPUT_MATLAB);
f2 = sprintf('%s/data/etats_pc.dat',X.RACINE_OUTPUT_MATLAB);
tnow = datevec(now);
snow = sprintf('%4d-%02d-%02d %02d:%02d:%02.0f',tnow);
dtmax = 60;             % dt max horloge (en secondes)
dtserveur = 2/24;    % dt max serveur decouverte (en jours)

% Charge les fichiers de définition des acquisitions
A = readacq;
P = readpc;

% Charge le fichier état des acquisitions
E = readetatpc;

fid = fopen(f2,'wt');

fprintf(fid,'-      ACQUIS %03d 100 %s -4 1\n',round(mean(E.pp)),snow);

% Retranscrit les lignes d'état acquisition
for i = 1:length(E.ss)
    tv = datevec(E.dh(i));
    fprintf(fid,'- %11s %03d %03d %4d-%02d-%02d %02d:%02d:%02.0f %+d %+d %d %d %s\n',E.ss{i},E.pp(i),E.aa(i),tv,E.tu(i),E.tz(i),E.dt(i),E.md(i),E.pc{i});
end

% Interprète l'état des PC
etats = ones(size(P.pc));
for i = 1:length(P.pc)
    k = strmatch(P.pc(i),E.pc);
    if ~isempty(k)
        pp = rmean(E.pp(k));
        aa = rmean(E.aa(k));
        tv = datevec(max(E.dh(k)));
        dt = max(E.dt(k));
        c1 = 'OK'; c2 = 'OK';
        st = '-';
        if isnan(aa)
            st = '?';
            c1 = 'Vérifier';
        end
        if dt > dtmax
            st = 'x';
            c2 = sprintf('%1.0f min',dt/60);
        end
        if aa == 0
            st = 'x';
            c1 = 'HS';
        end
        if pp == 0
            st = 'X';
            c1 = '!! PC PLANTÉ !!'; c2 = '';
        end
        if strcmp(st,'X'), etats(i) = 0; end
        fprintf(fid,'%s %11s %03d %03d %4d-%02d-%02d %02d:%02d:%02.0f -4 "%s" "%s"\n',st,P.ac{i},pp,aa,tv,c1,c2);
    end
end

% Vérifie la date de la routine (risque plantage decouverte)
tvserveur = max(E.dh);
if (tvserveur + dtserveur) < datenum(tnow)
    fprintf(fid,'X  decouverte 000 000 %4d-%02d-%02d %02d:%02d:%02.0f -4 "!! PB SUR LE SERVEUR !!" ""\n',datevec(tvserveur));
else
    fprintf(fid,'-  decouverte 100 100 %4d-%02d-%02d %02d:%02d:%02.0f -4 "OK" "OK"\n',datevec(tvserveur));
end

fclose(fid);
disp(sprintf('Fichier: %s créé.',f2));

% Copie des fichiers d'états stations + PC => "etats.txt"
unix(sprintf('cat %s %s > %s',f1,f2,fwww));
disp(sprintf('Fichier: %s mis à jour.',fwww));

% Commande les LEDS en cas de panne
%led = min([length(find(etats==0)),8]);
%if led
%    unix(sprintf('/root/OVSG/ecrirePP %d',2^round(led) - 1));
%else
%    unix('/root/OVSG/ecrirePP 0');
%end

timelog(rname,2)
