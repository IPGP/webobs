function mapnet(mat,tlim,ires,jres,kres)
%MAPNET Tracé des cartes de réseaux OVSG
%   MAPNET trace les cartes de réseaux individuels et de réseaux intégrés
%   avec les stations valides et actives au jour courant.
%
%   MAPNET(MAT,TLIM,IRES,JRES,KRES) utilise les arguments:
%       - MAT = 0 : retrace les fonds de cartes
%       - TLIM = DATENUM ou [YYYY,MM,DD] pour spécifier une date donnée,
%         ou [YYYY1,MM1,DD1;YYYY2,MM2,DD2] pour un intervalle: sélectionne les
%	  stations actives entre ces 2 dates
%       - IRES = indices des réseaux à tracer (dans l'ordre du fichier 
%	  "RESEAUX.conf")
%       - JRES = indices des cartes à tracer (voir l'ordre dans la variable 
%	  de "WEBOBS.conf" : MAP_EXTENSION_ORDER)
%       - KRES = indices des disciplines à tracer (voir l'ordre dans la variable
%	  de "RESEAUX.conf" : DISCIPLINE)
%
%   Les cartes de réseaux individuels indiquent les stations actives et les 
%   stations inactives en filigrane.
%   Les cartes de disciplines et réseaux intégrés n'indiquent que les stations actives.
%   Les stations "invalides" ne sont jamais affichées.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2002-08-24
%   Mise à jour : 2010-07-28

X = readconf;

scode = 'MAPNET';
timelog(scode,1)

rcode = 'RESEAUX';
stitre = 'Cartes des Réseaux Intégrés';
copyright = '(c) OVSG-IPGP';

tnow = datevec(now);
pftp = sprintf('%s/%s',X.RACINE_FTP,X.MAPNET_PATH_FTP);
css = sprintf('<LINK rel="stylesheet" type="text/css" href="/%s">',X.FILE_CSS);
feclair = 3;	% facteur d'éclaircissement des couleurs
cmap = load(sprintf('%s/landcolor0.dat',X.RACINE_DATA_MATLAB))/feclair + (1-1/feclair);
lmap = landcolor(256)/feclair + (1-1/feclair);
smap = seacolor(256)/feclair + (1-1/feclair);
noir = [0,0,0];
gris1 = .8*[1,1,1];
gris2 = .2*[1,1,1];
pax = [.07,.9];	% position et largeur relatives de l'axe de la carte
psz = [9.5,12];	% PaperSize (en pouces)
%cmap = gray/2 + .5;
M = {{'DOM','Dôme Soufrière',[643900,1774000,100],[1000,5,1465],'2',[1,2],120,'Dôme'}, ...
     {'SOU','Massif Soufrière',[644800,1772800,500],[500,10,1500],'5',[1,2],120,'Soufrière'}, ...
     {'SBT','Sud Basse-Terre',[650000,1765000,5000],[0,50,1500],'50',[1,2],120,'Sud B/T'}, ...
     {'GUA','Guadeloupe',[700000,1755000,10000],[0,100,1500],'',[1,2],120,'Guadeloupe'}, ...
     {'ANT','Petites Antilles',[],[],'',[5,4],120,'Antilles'}, ...
     {'DOM_BDO','Dôme Soufrière BD Ortho',[643450,1773650,100],[],'BD_Ortho_DOM',[7,8],120,'Dôme Photo'}, ...
     {'SOU_BDO','Massif Soufrière BD Ortho',[644500,1772250,500],[],'BD_Ortho_SOU',[7,8],120,'Soufrière Photo'}, ...
     {'SBT_BDO','Sud Basse-Terre BD Ortho',[652000,1765000,5000],[],'BD_Ortho_SBT',[7,8],120,'Sud B/T Photo'}, ...
     };
A = {{'SOU_traces.bln',[0,0,0],.1}, ...
     {'SOU_riv.bln',[0,.5,1],.2}, ...
     {'SOU_routes.bln',[0,0,0],.5}, ...
     {'SOU_batim.bln',[0,0,0],.5}};

[R,D] = readgr;
IA = readia;
if nargin < 1
    mat = 1;
end
if nargin < 2
	tlim = datevec(repmat(floor(now),[2,1]));
else
	if numel(tlim)==1
		tlim = datevec(tlim);
	end
	if size(tlim,1)==1
		tlim = repmat(tlim,[2,1]);
	end
end
if nargin < 3
    ires = 1:length(R);
end
if nargin < 4
    jres = 1:length(M);
end
if nargin < 5
    kres = 1:length(D.key);
end

% ===================================================================
% Tracé des fonds de carte (si inexistants ou forcés)
for j = 1:length(M)
    ffig = sprintf('%s/past/fond_%s.fig',X.RACINE_OUTPUT_MATLAB,M{j}{1});
    if ~exist(ffig) | mat==0
        disp(sprintf('Rebuild of the map background "%s"...',M{j}{2}))
        load(sprintf('%s/mnt_guad',X.RACINE_DATA_MATLAB));
        [IC,ccl,cfn] = readic;
        figure
        set(gcf,'PaperUnits','inches','PaperSize',psz,'PaperPosition',[.05,.05,7.9,8.9])
        switch M{j}{1}
        case 'ANT'
            f = sprintf('%s/etopo1_ant.grd',X.RACINE_DATA_MATLAB);
            [lon1,lat1,bat1] = igrd(f);
            disp(sprintf('File: %s imported.',f))
            h = dem(lon1,lat1,bat1,[-45,.5],lmap,NaN,smap,'dms','scale');
            %pcolor(lon1,lat1,bat1), shading flat
            %colormap(landsea(64)/2 + 1/2)
            %caxis([-7000 0]), colormap(flipud(hsv(256))/2 + .5)
            %axis tight, dd2dms(gca,1);
            % ombrage "manuel"...
            %[dbx,dby] = gradient(bat1);
            %[dbx,dby] = gradient(bat1,4*diff(lon1(1:2)));
            %gxy = dbx - dby;
            %omb = round(6*((max(max(gxy)) - gxy)/diff(minmax(gxy))).^4);
%            error('***')
            hold on
            %for ii = 1:length(lat1)
            %    for jj = 1:length(lon1)
            %        if omb(ii,jj)
            %            xo = rand(omb(ii,jj))*diff(lon1(1:2)) + lon1(jj);
            %            yo = rand(omb(ii,jj))*diff(lat1(1:2)) + lat1(ii);
            %            plot(xo,yo,'.','Color',gris2,'MarkerSize',.1)
            %        end
            %    end
            %    disp(sprintf('...shadow line %d/%d',ii,length(lat1)))
            %end
            set(gca,'FontSize',6)
            f = sprintf('%s/antille2.bln',X.RACINE_DATA_MATLAB);
            c_ant = ibln(f,0);
            disp(sprintf('File: %s imported.',f))
            hold on, pcontour(c_ant,gris2)
        case {'DOM_BDO','SOU_BDO','SBT_BDO'}
            f = sprintf('%s/%s.jpg',X.RACINE_DATA_MATLAB,M{j}{5});
            IM = imread(f);
            disp(sprintf('Image: %s imported.',f));
            imxy = load(sprintf('%s/%s.tab',X.RACINE_DATA_MATLAB,M{j}{5}));
            imagesc(imxy(1,1):imxy(1,3):imxy(1,2),imxy(2,2):-imxy(1,3):imxy(2,1),IM,[-50 255])
            set(gca,'YDir','normal'), colormap(gray)
            hold on, axis tight, axisgeo
            xe = M{j}{3}(1);  ye = M{j}{3}(2);
            plot(xe+M{j}{3}(3)*[-.5 .5],ye+[0 0],'-k','LineWidth',2)
            text(xe,ye,sprintf('%g km',M{j}{3}(3)/1e3),'FontSize',10,'FontWeight','bold', ...
                'HorizontalAlignment','center','VerticalAlignment','bottom')
            text(xe,ye,{' ','{\itBD Ortho IGN}','UTM20 WGS84'},'FontSize',6, ...
                'HorizontalAlignment','center','VerticalAlignment','top')
        otherwise
            eval(sprintf('[c,h] = contourf(x%s,y%s,z%s,%d:%d:%d);',M{j}{5},M{j}{5},M{j}{5},M{j}{4}));
            set(h,'EdgeColor',[1 1 1]*.3,'Linewidth',.1)
            hold on, axis tight, axisgeo; colormap(cmap)
            xe = M{j}{3}(1);  ye = M{j}{3}(2);
            plot(xe+M{j}{3}(3)*[-.5 .5],ye+[0 0],'-k','LineWidth',2)
            text(xe,ye,sprintf('%g km',M{j}{3}(3)/1e3),'FontSize',10,'FontWeight','bold', ...
                'HorizontalAlignment','center','VerticalAlignment','bottom')
            text(xe,ye,{sprintf('{\\itcourbes niveau %d m}',M{j}{4}(2)),'UTM20 Ste-Anne'},'FontSize',6, ...
                'HorizontalAlignment','center','VerticalAlignment','top')
        end
        if strcmp(M{j}{1},'DOM') | strcmp(M{j}{1},'SOU')
            for i = 1:length(A)
                f = sprintf('%s/%s',X.RACINE_DATA_MATLAB,A{i}{1});
                cc = ibln(f,0);
                disp(sprintf('File: %s imported.',f));
                h = pcontour(cc,A{i}{2});
                set(h,'Linewidth',A{i}{3})
            end
        end
        ax = axis;
        if j <= 4
            for i = 1:length(IC)
                if IC(i).map >= j & IC(i).est >= ax(1) & IC(i).est <= ax(2) & IC(i).nor >= ax(3) & IC(i).nor <= ax(4)
                    if IC(i).cde == 2
                        plot(IC(i).est,IC(i).nor,'s','MarkerFaceColor',gris1,'MarkerEdgeColor',gris2,'MarkerSize',6)
                    end
                    text(IC(i).est,IC(i).nor,IC(i).nom, ...
                        'HorizontalAlignment',IC(i).hal,'VerticalAlignment',IC(i).val,'Rotation',IC(i).rot, ...
                        'FontName',cfn{IC(i).cde},'FontWeight',IC(i).fwt,'FontAngle',IC(i).fag,'FontSize',IC(i).fsz,'Color',ccl{IC(i).cde})
                end
            end
        else
            for i = 1:length(IA)
                if IA(i).cde == 0
                    text(IA(i).lon,IA(i).lat,IA(i).nom, ...
                        'HorizontalAlignment',IA(i).hal,'VerticalAlignment',IA(i).val, ...
                        'FontWeight',IA(i).fwt,'FontAngle',IA(i).fag,'FontSize',IA(i).fsz,'Color',gris2)
                    
                end
            end
        end
        hgsave(gcf,ffig);
        disp(sprintf('File: %s created.',ffig));
        close
    end
end

% ===================================================================
% Tracé des cartes par réseau

for i = ires
    % chargement de toutes les stations (actives et inactives)
    ST = readst(strread(R(i).cod,'%s'),R(i).obs,1,tlim);
    nbs(i,2) = length(ST.cod);
    stcoo = [ST.utm,ST.geo,ST.wgs];
    
    for ii = 1:length(R(i).map)
        mks = [];  stxy = [];  cs = [];  ns = [];
        for j = 1:length(M)
            if strcmp(M{j}{1},R(i).map(ii));  break;  end
        end
        ffig = sprintf('%s/past/fond_%s.fig',X.RACINE_OUTPUT_MATLAB,M{j}{1});
        hgload(ffig);
        disp(sprintf('File: %s imported.',ffig));
        title({sprintf('Réseau %s',R(i).nom),''},'FontSize',14,'FontWeight','bold')
        set(get(gca,'Title'),'Visible','on')
        xy = axis;
        ix = M{j}{6}(1);
        iy = M{j}{6}(2);
    
        % Sélection et tracé des stations
        if length(ST.ali)
        	k = find(~strcmp(ST.ali,'-') & stcoo(:,ix)>=xy(1) & stcoo(:,ix)<=xy(2) & stcoo(:,iy)>=xy(3) & stcoo(:,iy)<=xy(4));
	else
		k = [];
	end
        % stations inactives
        kk = find(ST.ope(k)<0);
	nbs0 = length(kk);
        if ~isempty(kk)
            plot(stcoo(k(kk),ix),stcoo(k(kk),iy),'LineStyle','none','Marker',R(i).smk,'Color',filtre(noir,0),'MarkerFaceColor',filtre(R(i).rvb,0),'MarkerSize',R(i).ssz);
        end
        % stations actives
        kk = find(ST.ope(k)>0);
	nbs1 = length(kk);
        if ~isempty(kk)
            plot(stcoo(k(kk),ix),stcoo(k(kk),iy),'LineStyle','none','Marker',R(i).smk,'Color',filtre(noir,1),'MarkerFaceColor',filtre(R(i).rvb,1),'MarkerSize',R(i).ssz);
        end
        [nr,na,nt,TT] = tele(ST.cod(k),M{j}{6});
        %nr = relais(cellstr(char(ST(k).cod)),stutm(k,:));
        %text(stutm(:,1),stutm(:,2),cat(1,ST.cod),'FontWeight','bold')
        if ~isempty(k)
            stxy = [stxy;stcoo(k,[ix,iy])];
            if i==1 | isempty(cs)
                cs = ST.cod(k);  ns = ST.nom(k);
            else
                cs = [cs;ST.cod(k)];  ns = [ns;ST.nom(k)];
            end
            mks = [mks;ones(size(k))*R(i).ssz];
        end
    
        hold off
        axpos = get(gca,'position');
        set(gca,'position',[pax(1)-(strcmp(M{j}{1},'ANT')*.03),axpos(2),pax(2),axpos(4)])
        axpos = get(gca,'position');

        % Légende
        h = axes('Position',[pax(1),0.045,pax(2),.03]);
        plot([0,0,1,1,0],[0,1,1,0,0],'-k'), hold on
        xe = [.02,.25,.45,.6,.88];  ye = .5;
        plot(xe(1),ye,'Marker',R(i).smk,'MarkerEdgeColor','k','MarkerFaceColor',R(i).rvb,'MarkerSize',R(i).ssz)
        text(xe(1),ye,sprintf('   %s active ({\\bf%d}/%d)',R(i).snm,nbs1,length(k)),'Fontsize',8)
	if nbs0>0
		plot(xe(2),ye,'Marker',R(i).smk,'MarkerEdgeColor',filtre(noir,0),'MarkerFaceColor',filtre(R(i).rvb,0),'MarkerSize',R(i).ssz)
		text(xe(2),ye,sprintf('   %s inactive ({\\bf%d}/%d)',R(i).snm,nbs0,length(k)),'Fontsize',8)
	end
        if nr(1)
            plot(xe(3),ye,'Marker','p','MarkerEdgeColor','k','MarkerFaceColor',[1 1 1],'MarkerSize',6)
            text(xe(3),ye,sprintf('   relais radio ({\\bf%d})',nr),'Fontsize',8)
        end
        if ~isempty(TT)
            plot(xe(4)+[-.02 .02],[ye ye],'LineStyle',TT{1}{3},'Color',TT{1}{4},'LineWidth',.5)
            text(xe(4)+.02,ye,sprintf('   télémétrie %s ({\\bf%d})',TT{1}{2},nt),'Fontsize',8)
        end
        if na
            plot(xe(5),ye,'Marker','p','MarkerEdgeColor','k','MarkerFaceColor',[1 1 1],'MarkerSize',12)
            text(xe(5),ye,sprintf('    observatoire'),'Fontsize',8)
        end
        axis([0,1,0,1]), axis off

        matpad(copyright,.01); titpad(7);

        f = sprintf('%s_%s_MAP',R(i).rcd,M{j}{1});
        mkps2png(f,pftp,M{j}{7})
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
    disp(sprintf('File: %s imported.',ffig));
    title({sprintf('Réseaux %s',M{j}{2}),''},'FontSize',14,'FontWeight','bold')
    set(get(gca,'Title'),'Visible','on')
    if exist('xy','var')
        if strcmp(M{j}{1},'ANT')
            xy([3,1]) = utm2geo20(xy([1,3]));
            xy([4,2]) = utm2geo20(xy([2,4]));
        end
        plot(xy([1,2,2,1,1]),xy([3,3,4,4,3]),'k-','LineWidth',1)
    end
    xy = axis;
    nbs = zeros(length(R),2);
    nbt = zeros(0,2);
    ix = M{j}{6}(1);
    iy = M{j}{6}(2);
    for i = 1:length(R)
        if ~isempty(R(i).map)
            ST = readst(strread(R(i).cod,'%s'),R(i).obs,1,tlim);
            st = char(ST.cod);
            nbs(i,2) = length(ST.cod);
            stcoo = [ST.utm,ST.geo,ST.wgs];
        
            % Sélection des stations visibles (et actives)
	    if length(ST.ali)
            	k = find(~strcmp(ST.ali,'-') & stcoo(:,ix)>=xy(1) & stcoo(:,ix)<=xy(2) & stcoo(:,iy)>=xy(3) & stcoo(:,iy)<=xy(4) & ST.ope>0);
            else
	    	k = [];
	    end
	    nbs(i,1) = length(k);
            stcoo = stcoo(k,:);
            if ~isempty(k)
                stxy = [stxy;stcoo(:,[ix,iy])];
                if i==1 | isempty(cs)
                    cs = ST.cod(k);  ns = ST.nom(k);
                else
                    cs = [cs;ST.cod(k)];  ns = [ns;ST.nom(k)];
                end
                mks = [mks;ones(size(k))*R(i).ssz];
                % Tracé des stations
                plot(stcoo(:,ix),stcoo(:,iy),'LineStyle','none','Marker',R(i).smk, ...
                    'MarkerEdgeColor','k','MarkerFaceColor',R(i).rvb,'MarkerSize',R(i).ssz);
            end
            
            %text(stutm(:,1),stutm(:,2),cat(1,ST.cod),'FontWeight','bold')
            [nr,na,nt,TT,T] = tele(ST.cod(k),M{j}{6});
            if nt
                nbt(i,:) = [nt,TT{1}{1}];
            end
        end
    end    
    hold off
    axpos = get(gca,'position');
    set(gca,'position',[pax(1),axpos(2)+.13,pax(2),axpos(4)-.09])
    axpos = get(gca,'position');

    % Légende
    nbl = 11;  % nombre de lignes
    nbc = 3;   % nombre de colonnes
    h = axes('Position',[pax(1),0.045,pax(2),.14]);
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
    for i = 1:length(T)
        k = find(nbt(:,2)==i);
        if length(k)
            ii = ii + 1;
            xe = floor((ii-1)/nbl)*(1/nbc) + .03;
            ye = 0.92 - mod(ii-1,nbl)/(nbl+1);
            plot([xe-.04 xe],[ye ye],'LineStyle',T{i}{3},'Color',T{i}{4},'LineWidth',.5)
            text(xe,ye,sprintf('   Télémétrie %s ({\\bf%d} liaisons)',T{i}{2},sum(nbt(k,1))),'Fontsize',7)
        end
    end
    hold off, axis([0,1,0,1]), axis off
    text(.5,1,sprintf('{\\itTotal: {\\bf%d} réseaux - {\\bf%d} stations / sites de mesure}',nbr,sum(nbs(:,1))), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',10)

    matpad(copyright,.01);  titpad(12);

    f = sprintf('%s_%s',rcode,M{j}{1});
    mkps2png(f,pftp,M{j}{7})
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
            disp(sprintf('File: %s imported.',ffig));
            title(sprintf('Réseaux %s',R(kd(1)).dnm),'FontSize',14,'FontWeight','bold')
            set(get(gca,'Title'),'Visible','on')
            xy = axis;
            nbs = zeros(length(R),2);
            nbt = zeros(0,2);
            ix = M{j}{6}(1);
            iy = M{j}{6}(2);
            for kk = 1:length(kd)
                i = kd(kk);
                if ~isempty(R(i).map)
                    ST = readst(strread(R(i).cod,'%s'),R(i).obs,1,tlim);
                    st = char(ST.cod);
                    nbs(i,2) = length(ST.cod);
                    stcoo = [ST.utm,ST.geo,ST.wgs];
        
                    % Sélection des stations visibles (et actives)
		    if length(ST.ali)
                    	k = find(~strcmp(ST.ali,'-') & stcoo(:,ix)>=xy(1) & stcoo(:,ix)<=xy(2) & stcoo(:,iy)>=xy(3) & stcoo(:,iy)<=xy(4) & ST.ope>0);
		    else
			k = [];
		    end
                    nbs(i,1) = length(k);
                    stcoo = stcoo(k,:);
                    if ~isempty(k)
                        stxy = [stxy;stcoo(:,[ix,iy])];
                        if i==1 | isempty(cs)
                            cs = ST.cod(k);  ns = ST.nom(k);
                        else
                            cs = [cs;ST.cod(k)];  ns = [ns;ST.nom(k)];
                        end
                        mks = [mks;ones(size(k))*R(i).ssz];
                    
		        % Tracé des stations
                        plot(stcoo(:,ix),stcoo(:,iy),'LineStyle','none','Marker',R(i).smk, ...
                        'MarkerEdgeColor','k','MarkerFaceColor',R(i).rvb,'MarkerSize',R(i).ssz);
                    end
            
                    %text(stutm(:,1),stutm(:,2),cat(1,ST.cod),'FontWeight','bold')
                    [nr,na,nt,TT,T] = tele(ST.cod(k),M{j}{6});
                    if nt
                        nbt(i,:) = [nt,TT{1}{1}];
                    end
                end
            end    
            hold off
            axpos = get(gca,'position');
            set(gca,'position',[pax(1),axpos(2)+.13,pax(2),axpos(4)-.09])
            axpos = get(gca,'position');

            % Légende
            nbl = 5;  % nombre de lignes
            nbc = 2;   % nombre de colonnes
            %axes('Position',[0.6,0,.1,.35]), axis([0,1,0,1])
            h = axes('Position',[pax(1),0.045,pax(2),.13]);
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
            for i = 1:length(T)
                k = find(nbt(:,2)==i);
                if length(k)
                    ii = ii + 1;
                    xe = floor((ii-1)/nbl)*(1/nbc) + .03;
                    ye = 0.92 - mod(ii-1,nbl)/(nbl+1);
                    plot([xe-.04 xe],[ye ye],'LineStyle',T{i}{3},'Color',T{i}{4},'LineWidth',.5)
                    text(xe,ye,sprintf('   Télémétrie %s ({\\bf%d} liaisons)',T{i}{2},sum(nbt(k,1))),'Fontsize',8)
                end
            end
            hold off, axis([0,1,0,1]), axis off
            text(.5,1,sprintf('{\\itTotal: {\\bf%d} réseaux - {\\bf%d} stations / sites de mesure}',nbr,sum(nbs(:,1))), ...
                'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',10)

            matpad(copyright,.01);  titpad(12);

            f = sprintf('DISCIPLINE_%s_%s_MAP',D.key{g},M{j}{1});
            mkps2png(f,pftp,M{j}{7})
            imapnet(f,stxy,cs,ns,mks,xy,axpos)
            close
        end
    end
end

% Création de la page HTML reseaux_map.htm
jres = [5,4,3,8,2,7,1,6];
f = sprintf('%s/%s/%s_map.htm',X.RACINE_WEB,X.MATLAB_PATH_WEB,lower(rcode));
fid = fopen(f,'wt');
fprintf(fid,'<HTML><HEAD><TITLE>%s: %s %s</TITLE>%s</HEAD>\n',scode,stitre,datestr(now),css);
fprintf(fid,'<H2>%s</H2>',stitre);
for j = jres
    % Barres de liens
    fprintf(fid,'<P><A name="%s"></A>[',upper(M{j}{1}));
    for jj = jres
        if jj == j
            fprintf(fid,' <B>%s</B>',M{jj}{8});
        else
            fprintf(fid,' <A href="#%s"><B>%s</B></A>',upper(M{jj}{1}),M{jj}{8});
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
ss = textread(sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.MAPNET_FILE_NOTES),'%s','delimiter','\n');
for i = 1:length(ss)
    fprintf(fid,'%s\n',ss{i});
end
fprintf(fid,'</BODY></HTML>\n');
fclose(fid);
disp(sprintf('File: %s created.',f))


% Fabrication d'un ZIP des PS réseaux
f = sprintf('%s/RESEAUX_OVSG.zip',pftp);
unix(sprintf('zip -q -T -j -b /tmp -1 %s %s/images/RESEAUX_*.ps >&! /dev/null',f,X.RACINE_OUTPUT_MATLAB));
disp(sprintf('File: %s created.',f));
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
