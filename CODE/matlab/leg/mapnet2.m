function mapnet2(mat,ires,jres,kres)
%MAPNET2 Tracé des cartes de réseaux globaux
%   MAPNET2 trace les cartes de réseaux individuels et de réseaux intégrés
%
%   MAPNET2(MAT,IRES,JRES,KRES) utilise les arguments:
%       - MAT = 0 : retrace les fonds de cartes
%       - IRES = indices des réseaux à tracer (dans l'ordre des indices "net" du fichier "RESEAUX.conf")
%       - JRES = indices des cartes à tracer (WLD,... clés "map" utilisées dans RESEAUX.conf)
%       - KRES = indices des disciplines à tracer (voir liste RESEAUX.conf)

%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2007-01-23
%   Mise à jour : 2007-01-24

X = readconf;

scode = 'MAPNET';
timelog(scode,1)

rcode = 'RESEAUX';
stitre = 'Networks Maps';
copyright = '(c) IPGP';

tnow = datevec(now);
pftp = sprintf('%s/%s',X.RACINE_FTP,X.MAPNET_PATH_FTP);
css = sprintf('<LINK rel="stylesheet" type="text/css" href="/%s">',X.FILE_CSS);
feclair = 1.5;	% facteur d'éclaircissement des couleurs
cmap = load(sprintf('%s/landsea.dat',X.RACINE_DATA_MATLAB))/feclair + (1-1/feclair);
noir = [0,0,0];
gris1 = .8*[1,1,1];
gris2 = .2*[1,1,1];
%cmap = gray/2 + .5;
M = {{'WLD','World',[-180,180,-89,89],[-10000:2000:10000],120,'World'}, ...
        {'FRA','France',[-11,13,40,52],[-6000:500:6000],120,'France'}, ...
        {'ALG','Algérie',[-10,14,20,36],[-5000:500:5000],120,'Algérie'}, ...
        {'VIE','Vietnam',[95,125,5,35],[-8000:1000:8000],120,'Vietnam'}, ...
        {'TAF','TAAF',[40,80,-50,-35],[-6000:1000:6000],120,'TAAF'}, ...
     };

[R,D] = readgr;
if nargin < 1
    mat = 1;
end
if nargin < 2
    ires = 1:length(R);
end
if nargin < 3
    jres = 1:length(M);
end
if nargin < 4
    kres = 1:length(D.key);
end

% ===================================================================
% Tracé des fonds de carte (si inexistants ou forcés)

fmat = sprintf('%s/past/gtopo5.mat',X.RACINE_OUTPUT_MATLAB);
if exist(fmat) & mat~=0
    load(fmat,'lat5','lon5','gtp5');
    disp(sprintf('Fichier: %s importé.',fmat));
else
    % chargement du MNT GTOPO5 (en 2 fichiers)
    f = sprintf('%s/gtopo5_w.bin',X.RACINE_DATA_MATLAB);
    fid = fopen(f,'rb');
    w = fread(fid,[2161 2161],'int16')';
    fclose(fid);
    disp(sprintf('Fichier: %s importé.',f));
    f = sprintf('%s/gtopo5_e.bin',X.RACINE_DATA_MATLAB);
    fid = fopen(f,'rb');
    e = fread(fid,[2161 2161],'int16')';
    fclose(fid);
    disp(sprintf('Fichier: %s importé.',f));
    gtp5 = flipud([w(:,1:(end-1)),e]);
    clear e w
    lon5 = -180:5/60:180;
    lat5 = (-90:5/60:90)';
    save(fmat)
    disp(sprintf('Fichier: %s sauvé.',fmat));
end
for j = jres
    ffig = sprintf('%s/past/fond_%s.fig',X.RACINE_OUTPUT_MATLAB,M{j}{1});
    if ~exist(ffig) | mat==0
        disp(sprintf('Reconstruction du fond de carte "%s"...',M{j}{2}))

        [IC,ccl,cfn] = readic;
	
        figure
        set(gcf,'PaperSize',[7,8],'PaperPosition',[.05,.05,6.9,7.9])
	kx = find(lon5>=M{j}{3}(1) & lon5<=M{j}{3}(2));
	ky = find(lat5>=M{j}{3}(3) & lat5<=M{j}{3}(4));
        [c,h] = contourf(lon5(kx),lat5(ky),gtp5(ky,kx),M{j}{4});
        set(h,'EdgeColor',[1 1 1]*.3,'Linewidth',.1)
	set(gca,'XLim',M{j}{3}(1:2),'YLim',M{j}{3}(3:4));
        hold on, colormap(cmap), dd2dms(gca,1)
	set(gca,'FontSize',6)
	caxis([min(M{j}{4}),max(M{j}{4})]);
        ax = axis;
        for i = 1:length(IC)
            if IC(i).map >= j & IC(i).est >= ax(1) & IC(i).est <= ax(2) & IC(i).nor >= ax(3) & IC(i).nor <= ax(4)
                if IC(i).cde == 2
                    hold on
                    plot(IC(i).est,IC(i).nor,'s','MarkerFaceColor',gris1,'MarkerEdgeColor',gris2,'MarkerSize',6)
                end
                text(IC(i).est,IC(i).nor,IC(i).nom, ...
                    'HorizontalAlignment',IC(i).hal,'VerticalAlignment',IC(i).val,'Rotation',IC(i).rot, ...
                    'FontName',cfn{IC(i).cde},'FontWeight',IC(i).fwt,'FontAngle',IC(i).fag,'FontSize',IC(i).fsz,'Color',ccl{IC(i).cde})
            end
        end

        hgsave(gcf,ffig);
        disp(sprintf('Fichier: %s créé.',ffig));
        close
    end
end

% ===================================================================
% Tracé des cartes par réseau

for i = ires
    % chargement de toutes les stations (valides et invalides)
    ST = readst(strread(R(i).cod,'%s'),R(i).obs,0);
    nbs(i,2) = length(ST.cod);
    
    for ii = 1:length(R(i).map)
        mks = [];  stxy = [];  cs = [];  ns = [];
        for j = 1:length(M)
            if strcmp(M{j}{1},R(i).map(ii));  break;  end
        end
        ffig = sprintf('%s/past/fond_%s.fig',X.RACINE_OUTPUT_MATLAB,M{j}{1});
        hgload(ffig);
        disp(sprintf('Fichier: %s importé.',ffig));
        set(gcf,'PaperSize',[7,5])
        title(sprintf('Réseau %s',R(i).nom),'FontSize',14,'FontWeight','bold')
        set(get(gca,'Title'),'Visible','on')
        xy = axis;
        ix = M{j}{6}(1);
        iy = M{j}{6}(2);
        hold on
    
        % Sélection et tracé des stations
        k = find(~strcmp(ST.ali,'-') & ST.geo(:,2)>=xy(1) & ST.geo(:,2)<=xy(2) & ST.geo(:,1)>=xy(3) & ST.geo(:,1)<=xy(4));
        % stations invalides
        kk = find(ST.ope(k)==0);
        if ~isempty(kk)
            plot(ST.geo(k(kk),2),ST.geo(k(kk),1),'LineStyle','none','Marker',R(i).smk,'Color',filtre(noir,0),'MarkerFaceColor',filtre(R(i).rvb,0),'MarkerSize',R(i).ssz);
        end
        % stations valides
        kk = find(ST.ope(k));
        if ~isempty(kk)
            plot(ST.geo(k(kk),2),ST.geo(k(kk),1),'LineStyle','none','Marker',R(i).smk,'Color',filtre(noir,1),'MarkerFaceColor',filtre(R(i).rvb,1),'MarkerSize',R(i).ssz);
        end
        if ~isempty(k)
            stxy = [stxy;ST.geo(k,[2,1])];
            if i==1 | isempty(cs)
                cs = ST.cod(k);  ns = ST.nom(k);
            else
                cs = [cs;ST.cod(k)];  ns = [ns;ST.nom(k)];
            end
            mks = [mks;ones(size(k))*R(i).ssz];
        end
    
        hold off
        axpos = get(gca,'position');
        set(gca,'position',[axpos(1)-0.05,axpos(2)+.05,axpos(3)+0.1,axpos(4)-.05])
        axpos = get(gca,'position');

        % Légende
        h = axes('Position',[axpos(1),0.045,axpos(3),0.03]);
        plot([0,0,1,1,0],[0,1,1,0,0],'-k'), hold on
        xe = [.05,.3,.53,.82];  ye = .5;
        plot(xe(1),ye,'Marker',R(i).smk,'MarkerEdgeColor','k','MarkerFaceColor',R(i).rvb,'MarkerSize',R(i).ssz)
        text(xe(1),ye,sprintf('   %s ({\\bf%d}/%d)',R(i).snm,length(k),length(find(~strcmp(ST.ali,'-')))),'Fontsize',8)
        axis([0,1,0,1]), axis off

        matpad(copyright,0); titpad(7);

        f = sprintf('%s_%s_MAP',R(i).rcd,M{j}{1});
        mkps2png(f,pftp,M{j}{5})
        imapnet(f,stxy,cs,ns,mks,xy,axpos)
        close
    end
end

% ===================================================================
% Tracé des cartes de tous les réseaux

%M = {{'DOM','Dôme Soufrière',[642900,1773900],100,'surfl(x2,y2,z2,[-45,80]),shading flat,colormap(gray),view(2)'}, ...

for j = jres
    mks = [];  stxy = [];  cs = [];  ns = [];
    ffig = sprintf('%s/past/fond_%s.fig',X.RACINE_OUTPUT_MATLAB,M{j}{1});
    hgload(ffig);
    disp(sprintf('Fichier: %s importé.',ffig));
    title(sprintf('Réseaux %s',M{j}{2}),'FontSize',14,'FontWeight','bold')
    set(get(gca,'Title'),'Visible','on')
    hold on
    orient tall
    if exist('xy','var')
        plot(xy([1,2,2,1,1]),xy([3,3,4,4,3]),'k-','LineWidth',1)
    end
    xy = axis;
    nbs = zeros(length(R),2);
    ix = M{j}{6}(1);
    iy = M{j}{6}(2);
    for i = 1:length(R)
        if ~isempty(R(i).map{1})
            ST = readst(strread(R(i).cod,'%s'),R(i).obs);
            st = char(ST.cod);
            nbs(i,2) = length(ST.cod);
        
            % Sélection des stations visibles
            k = find(~strcmp(ST.ali,'-') & ST.geo(:,2)>=xy(1) & ST.geo(:,2)<=xy(2) & ST.geo(:,1)>=xy(3) & ST.geo(:,1)<=xy(4));
            nbs(i,1) = length(k);
            stcoo = ST.geo(k,:);
            if ~isempty(k)
                stxy = [stxy;stcoo(:,[2,1])];
                if i==1 | isempty(cs)
                    cs = ST.cod(k);  ns = ST.nom(k);
                else
                    cs = [cs;ST.cod(k)];  ns = [ns;ST.nom(k)];
                end
                mks = [mks;ones(size(k))*R(i).ssz];
                % Tracé des stations
                plot(stcoo(:,2),stcoo(:,1),'LineStyle','none','Marker',R(i).smk, ...
                    'MarkerEdgeColor','k','MarkerFaceColor',R(i).rvb,'MarkerSize',R(i).ssz);
            end
            
        end
    end    
    hold off
    axpos = get(gca,'position');
    set(gca,'position',[axpos(1)-0.05,axpos(2)+.2,axpos(3)+0.1,axpos(4)-.2])
    axpos = get(gca,'position');

    % Légend
    nbl = 8;  % nombre de lignes
    nbc = 2;   % nombre de colonnes
    %axes('Position',[0.6,0,.1,.35]), axis([0,1,0,1])
    h = axes('Position',[axpos(1),0.045,axpos(3),axpos(2)-.14]);
    plot([0,0,1,1,0],[0,1,1,0,0],'-k'), hold on
    nbr = 0;  ii = 0;
    for i = 1:length(R)
        if nbs(i,1)
            nbr = nbr + 1;  ii = ii + 1;
            xe = floor((ii-1)/nbl)*(1/nbc) + .03;
            ye = 0.92 - mod(ii-1,nbl)/(nbl+1);
            plot(xe,ye,'Marker',R(i).smk,'MarkerEdgeColor','k','MarkerFaceColor',R(i).rvb,'MarkerSize',R(i).ssz)
            text(xe,ye,sprintf('   %s ({\\bf%d}/%d %ss)',R(i).nom,nbs(i,:),R(i).snm),'Fontsize',7)
        end
    end
    hold off, axis([0,1,0,1]), axis off
    text(.5,1,sprintf('{\\itTotal: {\\bf%d} réseaux - {\\bf%d} stations / sites de mesure}',nbr,sum(nbs(:,1))), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',10)

    matpad(copyright,0);  titpad(12);

    f = sprintf('%s_%s',rcode,M{j}{1});
    mkps2png(f,pftp,M{j}{5})
    imapnet(f,stxy,cs,ns,mks,xy,axpos)
    close
end

% ===================================================================
% Tracé des cartes des disciplines

%error('***')
for g = kres
    kd = find(strcmp(cellstr(char(R.dis)),D.key(g)));
    mapd = cat(2,R(kd).map);
    for j = 1:length(M)
        mks = [];  stxy = [];  cs = [];  ns = [];
        if find(strcmp(M{j}{1},mapd));
            ffig = sprintf('%s/past/fond_%s.fig',X.RACINE_OUTPUT_MATLAB,M{j}{1});
            hgload(ffig);
            disp(sprintf('Fichier: %s importé.',ffig));
            title(sprintf('Réseaux %s',R(kd(1)).dnm),'FontSize',14,'FontWeight','bold')
            set(get(gca,'Title'),'Visible','on')
            orient tall
            xy = axis;
            nbs = zeros(length(R),2);
            ix = M{j}{6}(1);
            iy = M{j}{6}(2);
            for kk = 1:length(kd)
                i = kd(kk);
                if ~isempty(R(i).map{1})
                    ST = readst(strread(R(i).cod,'%s'),R(i).obs);
                    st = char(ST.cod);
                    nbs(i,2) = length(ST.cod);
        
                    % Sélection des stations visibles
			k = find(~strcmp(ST.ali,'-') & ST.geo(:,2)>=xy(1) & ST.geo(:,2)<=xy(2) & ST.geo(:,1)>=xy(3) & ST.geo(:,1)<=xy(4));
			nbs(i,1) = length(k);
			stcoo = ST.geo(k,:);
                    if ~isempty(k)
                        stxy = [stxy;stcoo(:,[2,1])];
                        if i==1 | isempty(cs)
                            cs = ST.cod(k);  ns = ST.nom(k);
                        else
                            cs = [cs;ST.cod(k)];  ns = [ns;ST.nom(k)];
                        end
                        mks = [mks;ones(size(k))*R(i).ssz];
                    end
            
                    % Tracé des stations
                    plot(stcoo(:,2),stcoo(:,1),'LineStyle','none','Marker',R(i).smk, ...
                        'MarkerEdgeColor','k','MarkerFaceColor',R(i).rvb,'MarkerSize',R(i).ssz);
                    %text(stutm(:,1),stutm(:,2),cat(1,ST.cod),'FontWeight','bold')
                end
            end    
            hold off
            axpos = get(gca,'position');
            set(gca,'position',[axpos(1)-0.05,axpos(2)+.2,axpos(3)+0.1,axpos(4)-.2])
            axpos = get(gca,'position');

            % Légende
            nbl = 5;  % nombre de lignes
            nbc = 2;   % nombre de colonnes
            %axes('Position',[0.6,0,.1,.35]), axis([0,1,0,1])
            h = axes('Position',[axpos(1),0.045,axpos(3),axpos(2)-.14]);
            plot([0,0,1,1,0],[0,1,1,0,0],'-k'), hold on
            nbr = 0;  ii = 0;
            for kk = 1:length(kd)
                i = kd(kk);
                if nbs(i,1)
                    nbr = nbr + 1;  ii = ii + 1;
                    xe = floor((ii-1)/nbl)*(1/nbc) + .03;
                    ye = 0.92 - mod(ii-1,nbl)/(nbl+1);
                    plot(xe,ye,'Marker',R(i).smk,'MarkerEdgeColor','k','MarkerFaceColor',R(i).rvb,'MarkerSize',R(i).ssz)
                    text(xe,ye,sprintf('   %s ({\\bf%d}/%d %ss)',R(i).nom,nbs(i,:),R(i).snm),'Fontsize',8)
                end
            end
            hold off, axis([0,1,0,1]), axis off
            text(.5,1,sprintf('{\\itTotal: {\\bf%d} réseaux - {\\bf%d} stations / sites de mesure}',nbr,sum(nbs(:,1))), ...
                'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',10)

            matpad(copyright,0);  titpad(12);

            f = sprintf('DISCIPLINE_%s_%s_MAP',D.key{g},M{j}{1});
            mkps2png(f,pftp,M{j}{5})
            imapnet(f,stxy,cs,ns,mks,xy,axpos)
            close
        end
    end
end

% Création de la page HTML reseaux_map.htm
jres = 1:length(M);
f = sprintf('%s/%s/%s_map.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB,lower(rcode));
fid = fopen(f,'wt');
fprintf(fid,'<HTML><HEAD><TITLE>%s: %s %s</TITLE>%s</HEAD>\n',scode,stitre,datestr(now),css);
fprintf(fid,'<H2>%s</H2>',stitre);
for j = jres
    % Barres de liens
    fprintf(fid,'<P><A name="%s"></A>[',upper(M{j}{1}));
    for jj = jres
        if jj == j
            fprintf(fid,' <B>%s</B>',M{jj}{6});
        else
            fprintf(fid,' <A href="#%s"><B>%s</B></A>',upper(M{jj}{1}),M{jj}{6});
        end
        if jj ~= jres(end)
            fprintf(fid,' |');
        end
    end
    fprintf(fid,' ]</P>\n');
    % Image
    map = sprintf('%s_%s',rcode,M{j}{1});
    fmap = sprintf('%s/data/%s.map',X.RACINE_OUTPUT_MATLAB,map);
    if exist(fmap,'file')
        ss = textread(fmap,'%s','delimiter','\n');
        fprintf(fid,'<P><IMG src="/images/graphes/%s.png" border="1" usemap="#map%d"></P>\n',map,j);
        fprintf(fid,'<MAP name="map%d">\n',j);
        for jj = 1:length(ss)
            fprintf(fid,'%s\n',ss{jj});
        end
        fprintf(fid,'</MAP>');
    else
        fprintf(fid,'<P><A href="/%s/%s_%s.htm"><IMG src="/%s/%s_%s.png" border="0"></A></P>\n',X.MAPS_PATH_WEB,rcode,M{j}{1},X.MKGRAPH_PATH_WEB,rcode,M{j}{1});
    end
end
fprintf(fid,'<A href="#%s"><B>Retour en haut</B></A>',M{1}{1});
% Notes
fprintf(fid,'<HR>');
ss = textread(sprintf('%s/%s',X.RACINE_DATA_WEB,X.MAPNET_FILE_NOTES),'%s','delimiter','\n');
for i = 1:length(ss)
    fprintf(fid,'%s\n',ss{i});
end
fprintf(fid,'</BODY></HTML>\n');
fclose(fid);
disp(sprintf('Fichier: %s créé.',f))


% Fabrication d'un ZIP des PS réseaux
f = sprintf('%s/RESEAUX.zip',pftp);
unix(sprintf('zip -q -T -j -b /tmp -1 %s %s/images/RESEAUX_*.ps >&! /dev/null',f,X.RACINE_OUTPUT_MATLAB));
disp(sprintf('Fichier: %s créé.',f));
%unix(sprintf('rm -f %s/images/RESEAUX_*.ps',X.RACINE_OUTPUT_MATLAB));

timelog(scode,2)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fonction d'éclaircissement des couleurs RVB
function y=filtre(x,f)
z = 2;
if f == 1
    y = x;
else
    y = (x/z + 1 - 1/z);
end
