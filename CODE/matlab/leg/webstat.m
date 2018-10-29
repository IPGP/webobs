function DOUT=webstat(mat,tlim,opt,nograph)

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-03-14
%   Mise à jour : 2003-06-05

if nargin < 1, mat = 0; end
if nargin < 2, tlim = []; end
if nargin < 3, opt = [1,1,1]; end
if nargin < 4, nograph = 0; end

tlim = 'all';

scode = 'WEBSTAT';
timelog(scode,1)

% Initialisation des variables
tu = -4;       % temps station
cmde = 200;    % code commande 'GET' effective
user = 'obsgua';

sname = 'Statistiques http://www.ovsg.univ-ag.fr';
SI = {'IPGP','OVSG','Coll','Autres'};
ST = {'Volume de données','Nombre d''accès'};
hovsg = '.ovsg.univ-ag.fr';
hovmp = '195.83.190.';
hovpf = '195.83.188.';
hwanadoo = '.abo.wanadoo.fr';
pdat = '/var/log/httpd';
phta = {'/home/httpd/html/.htaccess','/home/httpd/html/meteo/public/.htaccess'};
phtm = '/home/httpd/html/web/logs';
fext = {'.4','.3','.2','.1',''};
%fext = {''};
tnow = datevec(now);
stitre = sprintf('%s: %s',upper(scode),sname);
scopy = '\copyright FB, OVS-IPGP';

% Importation des adresses dans .htaccess
f = 'data/htaccess.dat';
unix(sprintf('grep -h "allow from" %s %s > %s',phta{1},phta{2},f));
[ip,ad,na,is] = textread(f,'allow from %s#%s%q%q');
disp(sprintf('Fichier: %s importé.',f))
nx = length(ip) + 1;
ip(1) = {'IP'};  ad(1) = {'IP'};  na(1) = {'Non autorisé'};  is(1) = {'Autres'};
ip(nx) = {hovsg};  ad(nx) = {hovsg};  na(nx) = {'Mise à jour du site'};  is(nx) = {'OVSG'};

% Extraction des fichiers LOG utilisateurs (simplifiés)
for i = 2:(nx-1)
    f = sprintf('%s/%s_%s',phtm,is{i},na{i});
    for j = 1:length(fext)
        if j == 1, rdir = '>'; else rdir = '>>'; end
        %unix(sprintf('grep -E "^%s " %s/access_log%s | awk ''{ print $1,$3,$4,$9,$10,$11 }'' %s "%s"',ad{i},pdat,fext{j},rdir,f));
        unix(sprintf('grep "%s" %s/access_log%s | awk ''{ print $1,$3,$4,$9,$10,$11 }'' %s "%s"',ad{i},pdat,fext{j},rdir,f));
    end
    disp(sprintf('Fichier: %s créé.',f));
end

% Importation des fichiers LOG courants
if ~mat
    ydeb = 2002;
    sdeb = 8;
    d = [];
    t = [];
    for i = 1:length(fext)
        f = sprintf('%s/access_log%s',pdat,fext{i});
        [hst,usr,dte,ut,cmd,cde,siz] = textread(f,'%s-%s%s%s%q%n%n%*[^\n]','delimiter',' ','whitespace','');
        disp(sprintf('Fichier: %s importé.',f))

        % astuce pour éliminer les noms de machines OVSG
        hh = fliplr(strjust(char(hst)));
        k = strncmp(cellstr(hh),fliplr(hovsg),length(hovsg));
        hst(k) = {hovsg};

        % astuce pour éliminer les noms de machines OVMP
        hh = char(hst);
        k = strncmp(cellstr(hh),hovmp,length(hovmp));
        hst(k) = {hovmp};

        % astuce pour éliminer les noms de machines OVPF
        hh = char(hst);
        k = strncmp(cellstr(hh),hovpf,length(hovpf));
        hst(k) = {hovpf};

        % astuce pour éliminer les noms de machines Wanadoo
        hh = fliplr(strjust(char(hst)));
        k = strncmp(cellstr(hh),fliplr(hwanadoo),length(hwanadoo));
        hst(k) = {hwanadoo};
    
        ts = char(dte); ts(:,1) = []; ts(:,[3 7]) = '-'; ts(:,12) = ' ';
        tt = datenum(ts);
        clear dte ut cmd ts

        dd = [ones(length(hst),1) ones(length(hst),1)*length(SI) cde siz/(2^20)];
        for i = 1:nx
            k = find(strcmp(SI,is(i)));
            if ~isempty(k)
                ii = k;
            else
                ii = 1;
            end
            switch i
            case 2
                k = find((strcmp(hst,ip(i)) | strcmp(hst,ad(i))) & strcmp(usr,user));
            case nx
                k = find((strcmp(hst,ip(i)) | strcmp(hst,ad(i))) & ~strcmp(usr,user) & ~isempty(usr));
            otherwise    
                k = find(strcmp(hst,ip(i)) | strcmp(hst,ad(i)));
            end
            if ~isempty(k)
                dd(k,1:2) = [i*ones(size(k)) ii*ones(size(k))];
            end
        end
        d = [d;dd];
        t = [t;tt];
    end
    tn = min(t);
    tm = max(t);

    % La matrice de données contient:
    %   1 = indice du site (utilisateur)
    %   2 = indice du laboratoire (groupe)
    %   3 = code commande
    %   4 = volume de données (en octet)

    % Statistiques par site
    for i = 1:nx
        k = find(d(:,1)==i);
        if isempty(k)
            t0 = 0;
        else
            t0 = t(k(end));
        end
        kk = find(d(k,3)==cmde);
        ds(i,:) = [sum(d(k(kk),4)) length(k) t0];
    end
    [sz,so] = sort(ds(:,3));

    % Statistique par laboratoire
    for i = 1:length(SI)
        k = find(d(:,2)==i);
        kk = find(d(k,3)==cmde);
        dl(i,:) = [sum(d(k(kk),4)) length(k)];
    end

    % Interprétation des arguments d'entrée de la fonction
    %	- t1 = temps min
    %	- t2 = temps max
    %	- structure G = paramètres de chaque graphe
    %		.ext = type de graphe (durée) "station_EXT.png"
    %		.lim = vecteur [tmin tmax]
    %		.fmt = numéro format de date (fonction DATESTR) pour les XTick
    %		.cum = durée cumulée pour les histogrammes (en jour)
    %		.mks = taille des points de données (fonction PLOT)

    % Décodage de l'argument TLIM
    if isempty(tlim)
        G = struct('ext',{'24h','30j','1an'}, ...
           'lim',{[tm-1 tm],[tm-30 tm],[tm-365 tm]}, ...
           'fmt',{15,19,1}, ...
           'cum',{1/24,1,1}, ...
           'mks',{4,2,1});
    end
    if ~isempty(tlim) & strcmp(tlim,'all')
        G = struct('ext','all','lim',[tn tm],'fmt',1,'cum',1,'mks',1);
    end
    if ~isempty(tlim) & ~ischar(tlim)
        if size(tlim,1) == 2
            t1 = datenum(tlim(1,:));
            t2 = datenum(tlim(2,:));
        else
            t2 = tm;
            t1 = tm - tlim;
        end
        G = struct('ext','xxx','lim',minmax([t1 t2]),'fmt',opt(1),'mks',opt(2),'cum',opt(3));
    end

    % Tracé des graphes
    for ig = 1:length(G)
    
        k = find(t>=G(ig).lim(1) & t<=G(ig).lim(2));
        figure(1), clf, orient tall
        col = jet(length(SI));

        % Infos générales
        subplot(5,3,1)
        axis([0 1 0 1]);
        text(0,1.5,{sprintf('du {\\bf%s}',datestr(G(ig).lim(1))), ...
               sprintf('au {\\bf%s}',datestr(G(ig).lim(2)))},'FontSize',10)
        hold on
        for i = 1:length(SI)
            xl = .05;
            yl = .9 - .13*(i-1);
            fill(.05+[0 0 xl xl],yl+.05*[-1 1 1 -1],col(i,:)), hold on
            text(xl+.05,yl,sprintf('  {\\bf%s} : {\\bf%1.1f} Mo - {\\bf%d} accès',SI{i},dl(i,:)), ...
                'VerticalAlignment','middle','Fontsize',8)
        end
        hold off, axis off

        suptitle(sprintf('%s: %s',upper(scode),sname))

        % Camembert par labo 'Files'
        subplot(5,3,2)
        h = pie(dl(:,1),strcmp(SI,'OVSG'));
        set(findobj(h,'Type','text'),'FontSize',7);
        hh = findobj(h,'Type','patch');
        for i = 1:length(hh)
            set(hh(i),'FaceColor',col(i,:));
        end
        text(-1.3,0,sprintf('en %s',ST{1}),'Rotation',90,'FontSize',8,'FontWeight','bold','HorizontalAlignment','center')
  
    
        % Camembert par labo 'Hits'
        subplot(5,3,3)
        h = pie(dl(:,2),strcmp(SI,'OVSG'));
        set(findobj(h,'Type','text'),'FontSize',7);
        hh = findobj(h,'Type','patch');
        for i = 1:length(hh)
            set(hh(i),'FaceColor',col(i,:));
        end
        text(-1.3,0,sprintf('en %s',ST{2}),'Rotation',90,'FontSize',8,'FontWeight','bold','HorizontalAlignment','center')

        % Statistiques par site
        subplot(5,3,[5 8 11 14])
        barh(log(1+ds(so,1:2)))
        v = get(gca,'XLim');
        %[legh,objh] = legend(ST,2);
        %set(legh,'position',[0 -1 diff(v) 1])
        %set(objh,'Fontsize',8)
        axis off
        title('Classement par ordre chronologique inverse')
        for i = 1:nx
            text(v(1),i,sprintf('%s - {\\bf%s}  ',na{so(i)},is{so(i)}),'HorizontalAlignment','right','Fontsize',8)
            if ds(so(i),3)
                dt0 = datestr(ds(so(i),3),1);
            else
                dt0 = 'indéterminé';
            end
            text(v(2),i,sprintf('%1.1f Mo - %d accès - %s',ds(so(i),1:2),dt0),'Fontsize',8)
        end
        pos = get(gca,'position');
        set(gca,'position',[pos(1)-0.05 pos(2)-.08 pos(3) pos(4)/1.1])
    
        % Statistiques temporelles
        subplot(5,1,2)
        tj = (G(ig).lim(1)+.5*G(ig).cum):G(ig).cum:(G(ig).lim(2)-.5*G(ig).cum);
        pj = xcum(t(k),d(k,2),tj);
        if G(ig).cum == 1
            hcum = 'journalier';
        else
            hcum = 'horaire';
        end
        bar(tj,pj)
        set(gca,'XLim',[G(ig).lim(1) G(ig).lim(2)],'FontSize',8)
        datetick('x',G(ig).fmt,'keeplimits')
        ylabel(sprintf('# accès %s',hcum'))
    
        colormap(summer)
        matpad(scopy);

        mkgraph(scode,'data')
    end
    close(1)
end

timelog(scode,2)
