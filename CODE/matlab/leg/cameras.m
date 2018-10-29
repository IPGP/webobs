function DOUT = cameras
%CAMERAS Traitement des données vidéo.
%
%       Spécificités du traitement:
%           - mise à jour de l'état (date dernière image)
%           - page unique contenant un lien vers les images du FTP
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-07-10
%   Mise à jour : 2009-10-06

% ===================== Chargement de toutes les données disponibles

X = readconf;
if nargin < 1, mat = 1; end
if nargin < 2, tlim = []; end
if nargin < 3, opt = [1,1,1]; end
if nargin < 4, nograph = 0; end

rcode = 'CAMERAS';
timelog(rcode,1);

G = readgr(rcode);
tnow = datevec(G.now);
ST = readst(G.cod,G.obs);

stype = 'T';

% ==== Initialisation des variables
tu = G.utc;            % temps station
samp = 10/1440;     % pas d'échantillonnage des données (en jour)
last = 1/24;        % délai d'estimation pour l'état de la station (en jour)

sname = G.nom;
scopy = '\copyright FB+AB, OVSG-IPGP';

nx = length(ST.cod);

for stn = 1:nx
    fim = sprintf('%s/%s.jpg',G.ftp,lower(ST.ali{stn}));
    f = sprintf('%s/%s',X.RACINE_FTP,fim);
    G.img{1}{stn} = sprintf('%s/%s',X.WEB_RACINE_FTP,fim);

    % Etat de la station
    if exist(f,'file')
        info = imfinfo(f,'jpg');
        if ~isempty(info)
            t = datesys2num(info.FileModDate);
            d = [info.Width,info.Height,info.BitDepth];
            if isempty(t)
                t = 0;
            end
        else
            t = 0;  d = 0;
        end
    else
        t = 0;  d = 0;
    end
    tlast(stn) = t;

    if t >= datenum(tnow)-last
        etats(stn) = 100;
        acquis(stn) = 100;
    else
        etats(stn) = 0;
        acquis(stn) = 0;
    end
    %if strcmp(ST.cod(stn),'HOUV1')
    %    etats(stn) = -1;
    %end
    sd = sprintf('%s %dx%d %d bits',f,d);
    mketat(etats(stn),t,sd,lower(ST.cod{stn}),tu,acquis(stn))
end    

mketat(etats,max(tlast),sprintf('%s %d %s',stype,nx,G.snm),rcode,tu,acquis)

G.sta = ST.cod;
G.ali = ST.ali;
%G.lnk = {{'Archives',sprintf('%s/Phenom/Photos/Tourelle',X.WEB_RACINE_FTP)},{'Météo-France','http://www.meteo.gp/'}};
htmgraph(G);

timelog(rcode,2)

