function sismoress_youngs(mat,n)
%SISMORESS Traitement des séismes ressentis
%       SISMORESS traite le dernier séisme localisé (hypoovsg.txt) et calcule le PGA théorique
%       sur l'archipel de Guadeloupe (loi d'atténuation [OVSG, 2004]). Si une zone dépasse 
%       un seuil d'daccélération, un communiqué est produit et envoyé par e-mail.
%
%       SISMORESS(MAT,N) recharge les informations géographiques (lignes de cotes, villes, etc...)
%       si MAT == 0 et fait le traitement sur les N derniers séismes localisés. Si N <= 0, fait
%       le calcul sur un séisme test -N.

%   Auteur: F. Beauducel, OVSG-IPGP
%   Création : 2005-01-12
%   Mise à jour : 2007-08-09
%   Dernière modification : <28 oct 2008 17:16:55 Alexis Bosson>

X = readconf;

rcode = 'SHAKEMAPS';
nom_loi = {'B-Cube, rocher';
	'B-Cube, sol';
	'Youngs et al. 1997, rocher';
	'Youngs et al. 1997, sol';
	'Chang et al., 2001, shallow';
	'Chang et al., 2001, subduction';
	'Fukushima et Tanaka, 1990';
	'Atkinson et Boore, 2003';
	'Sadigh et al., 1997';
	'Ambraseys et al., 2005';
	'Kanno et al., 2006 shallow';
	'Kanno et al., 2006 deep';
	};
rep_loi = {'b3-rocher';
	'b3-sol';
	'youngs-1997-rocher';
	'youngs-1997-sol';
	'chang-2001-shallow';
	'chang-2001-subd';
	'fukushima-1990';
	'atkinson-2003';
	'sadigh-1997';
	'ambraseys-2005';
	'kanno-2006-shallow';
	'kanno-2006-subd';
};

timelog(rcode,1);

if nargin < 1,  mat = 1;  end
if nargin < 2,  n = 1;  end

if n <= 0
    test = abs(n) + 1;
    n = 1;
else
    test = 0;
end

% Définition des variables
xylim = [-64 -59.7 14.25 18.4];                % limites carte hypo (en °)
dxy = .05;                                       % pas de la grille XY (en °)
pgamin = 2;                                      % PGA minimum (en milli g)
pgamsk = [1,2,5,10,20,50,100,200,500,1000,2000,10000000]; % limites PGA équivalent échelle MSK (en milli g)
lwmsk = [.1,.25,.5,1,1.5,2,2.5,3,3.5,4,5,6];       % largeur des lignes iso
%nommag = {'micro','minor','light','moderate','strong','major','great',''};
nommag = {'microséisme','séisme mineur','faible séisme','séisme modéré','séisme important','séisme fort','très fort séisme','séisme majeur'}; % <2, 2-3, 3-4, 4-5, 5-6, 6-7, 7-8, >8
nommsk = {'non ressentie';
          'rarement ressentie';
          'faiblement ressentie';
          'largement ressentie';
          'secousse forte';
          'dégâts légers probables';
          'dégâts probables';
          'dégâts importants probables';
          'destructions probables';
          'destructions importantes probables';
          'catastrophe probable';
	  'bug'};
nomres = {'non ressenti';'très faible';'faible';'légère';'modérée';'forte';'très forte';'sévère';'violente';'extrême';'bug'};
nomdeg = {'aucun';'aucun';'aucun';'aucun';'très légers';'légers';'modérés';'moyens';'importants';'généralisés';'bug'};
tsok = [2,13,14,15];			% types de séisme OK pour calcul B3

dhpmin = 5;									% distance hypocentrale minimale (effet de saturation) en km
latkm = 6370*pi/180;                        % valeur du degré latitude (en km)
lonkm = latkm*cos(16*pi/180);               % valeur du degré longitude (en km)
gris = .8*[1,1,1];                          % couleur gris clair
mer = [.7,.9,1];							% couleur bleu mer
ppi = 150;                                  % résolution PPI

% Colormap JET dégradée
sjet = jet(256);
z = repmat(linspace(0,1,length(sjet))',1,3);
sjet = sjet.*z + (1-z);

%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% DEBUG
% Faire une boucle pour utiliser tous les hypoovsg_* ou remplacer tail
%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
f1 = sprintf('%s/Sismologie/Hypocentres/hypoovsg_*.txt',X.RACINE_FTP);
ftmp = '/tmp/lasthypo.ps';
mtmp = '/tmp/mailb3.txt';
ttmp = '/tmp/hypob3.txt';
flogo1 = sprintf('%s/%s',X.RACINE_WEB,X.IMAGE_LOGO_OVSGIPGP);
%flogo2 = sprintf('%s/%s',X.RACINE_WEB,X.IMAGE_LOGO_OVSG);
flogo3 = sprintf('%s/%s',X.RACINE_WEB,X.IMAGE_LOGO_B3);

% Test: chargement si la sauvegarde Matlab existe
f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,rcode);
if mat & exist(f_save,'file')
    load(f_save,'c_pta','A1','A3','CS','IC');
    disp(sprintf('Fichier: %s importé.',f_save))
else
    disp('Pas de sauvegarde Matlab. Chargement de toutes les données...');
    f = sprintf('%s/antille2.bln',X.RACINE_DATA_MATLAB);
    c_ant = ibln(f);
    c_pta = econtour(c_ant,[],xylim);
    A1 = imread(flogo1);
    %A2 = imread(flogo2);
    A3 = imread(flogo3);
    f = sprintf('%s/Infos_Communes_Richter.txt',X.RACINE_FICHIERS_CONFIGURATION);
    [IC.lon,IC.lat,IC.nom] = textread(f,'%n%n%q','commentstyle','shell');
    CS = readcs;
   
    save(f_save);
    disp(sprintf('Fichier: %s sauvegardé.',f_save))
end


% Chargement des séismes localisés
unix(sprintf('tail -q -n %d %s > %s',n + 1,f1,ttmp));    % NB: N + 1 car READHYP ignore la première ligne du fichier TTMP
DH = readhyp(ttmp);

% Construction de la grille XY
[x,y] = meshgrid(xylim(1):dxy:xylim(2),xylim(3):dxy:xylim(4));
if test
    nb=1;
else
    nb=length(DH.tps);
end
for id_loi = [2,3,4,12]
disp(sprintf('Loi d''atténuation : %s',nom_loi{id_loi}));
txtb3 = sprintf('(c) OVSG-IPGP %s - Calculs basés sur localisation OVSG + loi d''atténuation %s',datestr(now,'yyyy'),nom_loi{id_loi});
pgra = sprintf('%s/Sismologie/shakemap/%s',X.RACINE_FTP,rep_loi{id_loi});
f2 = sprintf('%s/lasthypo.txt',pgra);
f3 = sprintf('%s/lasthypo.pdf',pgra);
f4 = sprintf('%s/lasthypo.jpg',pgra);
for i = 1:nb
	if test
	    switch i-1
	    case 0 
		DH.tps(i) = datenum(2009,02,05,06,08,04); DH.lat(i) = 16.0465; DH.lon(i) = -60.6277; DH.dep(i) = 44; DH.mag(i) = 4.5; DH.typ(i) = 2;
	    otherwise
	    end
    end
    % ==========================================================

	vtps = datevec(DH.tps(i));
    fnam = sprintf('%4d%02d%02dT%02d%02d%02.0f_b3',vtps);
	pam = sprintf('%4d/%02d',vtps(1:2));
    if test
        fgra = sprintf('%s/simulations/%s.pdf',pgra,fnam);
	if (~exist(sprintf('mkdir -p %s/simulations',pgra),'dir'))
		unix(sprintf('mkdir -p %s/simulations',pgra));
	end
		ftxt = sprintf('%s/simulations/%s.txt',pgra,fnam);
    else
        fgra = sprintf('%s/ressentis/%s/%s.pdf',pgra,pam,fnam);
		unix(sprintf('mkdir -p %s/ressentis/%s',pgra,pam));
		ftxt = sprintf('%s/traites/%s/%s.txt',pgra,pam,fnam);
		unix(sprintf('mkdir -p %s/traites/%s',pgra,pam));
    end

    
%     if (~exist(ftxt,'file') | test) & ~isempty(find(DH.typ(i) == tsok))
    if (~exist(ftxt,'file')) & ~isempty(find(DH.typ(i) == tsok))
	    if i == 1
		figure, orient tall
		set(gcf,'PaperType','A4');
		pps = [.2,.2,7.8677,11.2929];
		set(gcf,'PaperPosition',pps);
	    end
    
		tnow = now;
		%Pour mettre à jour les cartes en gardant la date de création du fichier...
		%if ~test & exist(fgra,'file')
		%    D = dir(fgra);
		%    tnow = datesys2num(D.date);
		%end

        % distance hypocentrale sur la grille XY
        dhp = sqrt(((x - DH.lon(i))*lonkm).^2 + ((y - DH.lat(i))*latkm).^2 + DH.dep(i).^2);
        % PGA max au sol (loi majorée x3) sur la grille XY
	pga = attenuation(id_loi,DH.mag(i),dhp,DH.dep(i));
		
        %vpga = interp2(x,y,pga,IC.lon,IC.lat);
        %vdhp = interp2(x,y,dhp,IC.lon,IC.lat);
		vdhp = sqrt(((IC.lon - DH.lon(i))*lonkm).^2 + ((IC.lat - DH.lat(i))*latkm).^2 + DH.dep(i).^2);
		k = find(vdhp < dhpmin);
		vdhp(k) = dhpmin;
	vpga = attenuation(id_loi,DH.mag(i),vdhp,DH.dep(i));
		
        [xx,iv] = sort(-vpga);
        if max(vpga) >= pgamin
            ress = 1;
            k = find(vpga >= pgamin);
            vmsk = ones(size(k));
            ss = cell(size(k));
            for ii = 1:length(ss)
                kk = find(vpga(iv(ii)) < pgamsk);
                vmsk(ii) = kk(1) - 1;
                og = 10^(floor(log10(vpga(iv(ii)))) - 1);
                ss{ii} = sprintf('{\\bf%s à %s} : %s (%1.0f mg)',romanx(vmsk(ii)-1),romanx(vmsk(ii)),IC.nom{iv(ii)},round(vpga(iv(ii))/og)*og);
            end
        else
            ress = 0;
        end

        % Archivage du traitement
        fid = fopen(ftxt,'wt');
        fprintf(fid,repmat('*',1,80));
        fprintf(fid,'\n* Traitement automatique Loi d''atténuation %s\n',nom_loi{id_loi});
        fprintf(fid,'* %s (locales)\n',datestr(tnow));
        fprintf(fid,'* Hypocentre OVSG: %s TU, MD = %1.1f, Type %s\n',datestr(DH.tps(i)),DH.mag(i),CS{2,DH.typ(i)});
        fprintf(fid,'*                  %g °N %g °E %g km\n',DH.lat(i),DH.lon(i),DH.dep(i));
        fprintf(fid,'* Distance hypocentrale et PGA calculé :\n');
        for ii = 1:length(vpga)
            fprintf(fid,'\t%s: %0.1f km - %g mg\n',IC.nom{iv(ii)},vdhp(iv(ii)),vpga(iv(ii)));
        end
        fprintf(fid,repmat('*',1,80));
        fclose(fid);
        disp(sprintf('Fichier: %s créé.',ftxt));
        
        % ------------------------------------------------------------------------------
        % Si ressenti, contruction de la page et traitements
        if ress | test
            clf
    
            isz1 = size(A1);
            %isz2 = size(A2);
            isz3 = size(A3);

            pos = [0.03,1-isz1(1)/(ppi*pps(4)),isz1(2)/(ppi*pps(3)),isz1(1)/(ppi*pps(4))];
            % logos IPGP et OVSG
            h1 = axes('Position',pos,'Visible','off');
            image(A1), axis off
            %pos = [sum(pos([1,3])),1-isz2(1)/(ppi*pps(4)),isz2(2)/(ppi*pps(3)),isz2(1)/(ppi*pps(4))];
            %h2 = axes('Position',pos,'Visible','off');
            %image(A2), axis off
            % en-tete
            h3 = axes('Position',[sum(pos([1,3]))+.03,pos(2),.95-sum(pos([1,3])),pos(4)]);
            if test
                text(.3,0,'Exercice','FontSize',72,'FontWeight','bold','Color',[0,1,1],'Rotation',15,'HorizontalAlignment','center');
            end
            text(0,1,{'Rapport préliminaire de séisme','concernant la Guadeloupe'}, ...
                'VerticalAlignment','top','FontSize',18,'FontWeight','bold','Color',.3*[0,0,0]);
            text(0,0,{'{\bfObservatoire Volcanologique et Sismologique de Guadeloupe - IPGP}', ...
                      'Le Houelmont - 97113 Gourbeyre - Guadeloupe (FWI)', ...
                      'Tél: +590 (0)590 99 11 33 - Fax: +590 (0)590 99 11 34 - infos@ovsg.univ-ag.fr - www.ipgp.fr'}, ...
                 'VerticalAlignment','bottom','FontSize',8,'Color',.3*[0,0,0]);
            set(gca,'YLim',[0,1]), axis off
            % logo B3
            %pos = [.95 - isz3(2)/(ppi*pps(4)),1-isz3(1)/(ppi*pps(4)),isz3(2)/(ppi*pps(3)),isz3(1)/(ppi*pps(4))];
            %h4 = axes('Position',pos,'Visible','off');
            %image(A3), axis off

            % titre
            h5 = axes('Position',[.05,.75,.9,.15]);
            if ress
                text(1,1,sprintf('Gourbeyre, le %s %s %s %s locales',datestr(tnow,'dd'),traduc(datestr(tnow,'mmm')),datestr(tnow,'yyyy'),datestr(tnow,'HH:MM')), ...
                     'horizontalAlignment','right','VerticalAlignment','top','FontSize',10);
            end
            dtiso = sprintf('%s-%s-%s %s TU',datestr(DH.tps(i),'yyyy'),datestr(DH.tps(i),'mm'),datestr(DH.tps(i),'dd'),datestr(DH.tps(i),'HH:MM:SS'));
            dtu = sprintf('%s %s %s %s %s TU',traduc(datestr(DH.tps(i),'ddd')),datestr(DH.tps(i),'dd'),traduc(datestr(DH.tps(i),'mmm')),datestr(DH.tps(i),'yyyy'),datestr(DH.tps(i),'HH:MM:SS'));
            dtl = sprintf('{\\bf%s %s %s %s à %s}',traduc(datestr(DH.tps(i)-4/24,'ddd')),datestr(DH.tps(i)-4/24,'dd'),traduc(datestr(DH.tps(i)-4/24,'mmm')),datestr(DH.tps(i)-4/24,'yyyy'),datestr(DH.tps(i)-4/24,'HH:MM'));
            text(.5,.7,{sprintf('Magnitude %1.1f, %05.2f°N, %05.2f°W, profondeur %1.0f km',DH.mag(i),DH.lat(i),-DH.lon(i),DH.dep(i)),dtu}, ...
                 'horizontalAlignment','center','VerticalAlignment','middle','FontSize',14,'FontWeight','bold');
            
            % Texte du communiqué : paramètres à afficher
            s_qua = nommag{max([1,floor(DH.mag(i))])};
            s_mag = sprintf('%1.1f',DH.mag(i));
            s_vaz = boussole(atan2(DH.lat(i) - IC.lat(iv(1)),DH.lon(i) - IC.lon(iv(1))),1);
			epi = sqrt(((IC.lon(iv(1)) - DH.lon(i))*lonkm).^2 + ((IC.lat(iv(1)) - DH.lat(i))*latkm).^2);
            %epi = sqrt(vdhp(iv(1))^2 - DH.dep(i)^2);
            if epi < 1
                s_epi = 'moins de 1 km';
            else
                s_epi = sprintf('%1.0f km',epi);
            end
            s_gua = sprintf('%s',IC.nom{iv(1)});
            if DH.dep(i) < 1
                s_dep = 'moins de 1 km';
            else
                s_dep = sprintf('%1.0f km',DH.dep(i));
            end
			s_dhp = sprintf('%1.0f km',sqrt(epi^2 + DH.dep(i)^2));
	        s_typ = CS{3,DH.typ(i)};
            % NB: arrondi du PGA à 2 chiffres significatifs...
            og = 10^(floor(log10(vpga(iv(1)))) - 1);
            s_pga = sprintf('%1.0f mg',round(vpga(iv(1))/og)*og);
            if vmsk(1) > 1
                s_msk = sprintf('{\\bf%s à %s} (%s)',romanx(vmsk(1)-1),romanx(vmsk(1)),nommsk{vmsk(1)});
            else
                s_msk = sprintf('{\\bfI} (%s)',nommsk{1});
            end
            s_txt = {sprintf('Un %s (magnitude {\\bf%s} sur l''Échelle de Richter) a été enregistré le %s',s_qua,s_mag,dtl), ...
                         sprintf('(heure locale) et identifié d''origine {\\bf%s}. L''épicentre a été localisé à  {\\bf%s} %s de',s_typ,s_epi,s_vaz), ...
                         sprintf('{\\bf%s}, à %s de profondeur (soit une distance hypocentrale d''environ %s). Ce séisme a pu',s_gua,s_dep,s_dhp), ...
                         sprintf('générer, dans les zones les plus proches de l''épicentre et sur certains types de sols, une accélération horizontale'), ...
                         sprintf('théorique de {\\bf%s} (*), correspondant à une intensité %s.',s_pga,s_msk)};
            text(0,0,s_txt,'horizontalAlignment','left','VerticalAlignment','bottom','FontSize',10);
            set(gca,'XLim',[0,1],'YLim',[0,1]), axis off
            
            % carte
            %pos0 = [.092,.08,.836,.646];
            pos0 = [.055,.126,.9,.600];
            h5 = axes('Position',pos0);
            pcolor(x,y,log10(pga)), shading flat, colormap(sjet), caxis(log10(pgamsk([1,10])))
            hold on
            pcontour(c_pta,[],gris), axis(xylim)
            h = dd2dms(gca,0);
            set(h,'FontSize',7)
            for ii = 2:length(pgamsk)
                [cs,h] = contour(x,y,pga,pgamsk([ii,ii]));
                set(h,'LineWidth',lwmsk(ii),'EdgeColor','k');
                if ~isempty(h)
                    hl = clabel(cs,h);
                    set(hl,'FontSize',8);
                end
            end
            % épicentre
            plot(DH.lon(i),DH.lat(i),'p','MarkerSize',10,'MarkerEdgeColor','k','MarkerFaceColor','w','LineWidth',1.5)
            
            % tableau des communes
            if ress
                ssl = [{'{\bfIntensités MSK supposées dans}';'{\bfles communes et accélérations}';'{\bfthéoriques maximales :}';''};ss];
                if length(ss) < length(IC.lat)
                    ssl = [ssl;{'';'{\itnon ressenti dans les autres}';'{\itcommunes de la Guadeloupe.}'}];
                end
                h = rectangle('Position',[xylim(1)+.05,xylim(3)+.05,1.2,(length(ssl) + 1)*.08]);
                set(h,'FaceColor','w')
                text(xylim(1)+.1,xylim(3)+.1,ssl,'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',8);
            end
            hold off
            
            % copyright
            text(xylim(2)+.03,xylim(3),txtb3,'Rotation',90,'HorizontalAlignment','left','VerticalAlignment','top','FontSize',7);
            
            % encart zoom zone épicentrale
            if epi < 20
                if epi > 8
                    depi = 20;  % largeur de l'encart (en km)
                    dsc = 10;   % échelle des distances (en km)
                    fsv = 9;    % taille police noms villes
                    msv = 8;    % taille marqueurs villes
                else
                    depi = 10;
                    dsc = 5;
                    fsv = 11;
                    msv = 10;
                end
                ect = [DH.lon(i) + depi/lonkm*[-1,1],DH.lat(i) + depi/latkm*[-1,1]];
                % tracé du carré sur la carte principale
                hold on
                plot(ect([1,2,2,1,1]),ect([3,3,4,4,3]),'w-','LineWidth',2);
                plot(ect([1,2,2,1,1]),ect([3,3,4,4,3]),'k-','LineWidth',.1);
                hold off
                w1 = .3;    % taille relative de l'encart (par rapport à la page)
                h6 = axes('Position',[pos0(1)+pos0(3)-(w1+.01),pos0(2)+pos0(4)-(w1+.01)*pps(3)/pps(4),w1,w1*pps(3)/pps(4)]);
                pcontour(c_pta,[],gris), axis(ect), set(gca,'FontSize',6,'XTick',[],'YTick',[])
                hold on
                plot(ect([1,2,2,1,1]),ect([3,3,4,4,3]),'k-','LineWidth',2);
                plot(DH.lon(i),DH.lat(i),'p','MarkerSize',20,'MarkerEdgeColor','k','MarkerFaceColor','w','LineWidth',2)
                k = find(IC.lon > ect(1) & IC.lon < ect(2) & IC.lat > ect(3) & IC.lat < ect(4));
                plot(IC.lon(k),IC.lat(k),'s','MarkerSize',msv,'MarkerEdgeColor','k','MarkerFaceColor','k')
                text(IC.lon(k),IC.lat(k)+.05*depi/latkm,IC.nom(k),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',fsv,'FontWeight','bold')
                xsc = ect(1) + .75*diff(ect(1:2));
                ysc = ect(3)+.03*diff(ect(3:4));
                plot(xsc+dsc*[-.5,.5]/lonkm,[ysc,ysc],'-k','LineWidth',2)
                text(xsc,ysc,sprintf('%d km',dsc),'HorizontalAlignment','center','VerticalAlignment','bottom','FontWeight','bold')
				for ii = 1:length(pgamsk)
					% nouvelle grille + serrée
					[xz,yz] = meshgrid(linspace(ect(1),ect(2),100),linspace(ect(3),ect(4),100));
					dhpz = sqrt(((xz - DH.lon(i))*lonkm).^2 + ((yz - DH.lat(i))*latkm).^2 + DH.dep(i).^2);
					pgaz = attenuation(id_loi,DH.mag(i),dhpz,DH.dep(i));
					[cs,h] = contour(xz,yz,pgaz,pgamsk([ii,ii]));
					set(h,'LineWidth',.1,'EdgeColor','k');
					if ~isempty(h)
						hl = clabel(cs,h);
						set(hl,'FontSize',8);
					end
				end
                hold off
            end
            
            
            % Tableau des intensités
            h7 = axes('Position',[.03,.02,.95,.07]);
            sz = length(pgamsk) - 1;
            % échelle de couleurs
            xx = linspace(2,sz+2,256)/(sz+2);
            %pcolor(xx,repmat([0;1/4],[1,length(xx)]),repmat(linspace(log10(pgamsk(1)),log10(pgamsk(10)),length(xx)),[2,1]))
            shading flat, caxis(log10(pgamsk([1,10])))
            hold on
            % bordures
            plot([0,0,1,1,0],[0,1,1,0,0],'-k','LineWidth',2);
            for ii = 1:3
                plot([0,1],[ii,ii]/4,'-k','LineWidth',.1);
            end
            for ii = 2:(sz+1)
                plot([ii,ii]/(sz+2),[0,1],'-k','LineWidth',.1);
            end
            text(1/(sz+2),3.5/4,'{\bfPerception Humaine}','HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
            for ii = 1:sz
                xx = (ii + 1.5)/(sz+2);
                text(xx,3.5/4,nomres{ii},'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
            end
            text(1/(sz+2),2.5/4,'{\bfDégâts Probables}','HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
            for ii = 1:sz
                xx = (ii + 1.5)/(sz+2);
                text(xx,2.5/4,nomdeg{ii},'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
            end
            text(1/(sz+2),1.5/4,'{\bfAccélérations (mg)}','HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
            for ii = 1:sz
                xx = (ii + 1.5)/(sz+2);
                switch ii
                case 1 
                    ss = sprintf('< %g',pgamsk(ii+1));
                case sz
                    ss = sprintf('> %g',pgamsk(ii));
                otherwise
                    ss = sprintf('%g - %g',pgamsk([ii,ii+1]));
                end
                text(xx,1.5/4,ss,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
            end
            text(1/(sz+2),.5/4,'{\bfIntensités MSK}','HorizontalAlignment','center','VerticalAlignment','middle','FontSize',7);
            for ii = 1:sz
                xx = (ii + 1.5)/(sz+2);
                switch ii
                case sz
                    ss = sprintf('%s+',romanx(ii));
                otherwise
                    ss = romanx(ii);
                end
                text(xx,.5/4,ss,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','middle','FontSize',9);
            end
            text(0,0,{'(*) {\bfmg} = "milli gé" est une unité d''accélération correspondant au millième de la pesanteur terrestre'}, ...
                'HorizontalAlignment','left','VerticalAlignment','top','FontSize',8);
            hold off
            set(gca,'XLim',[0,1],'YLim',[0,1]), axis off                    
            %h7 = axes('Position',[.05,0,.88,.05]);
            %text(0,0,{'(*) {\bfmg} = "milli gé" est une unité d''accélération correspondant au millième de la pesanteur terrestre', ...
            %          '(**) Définition de l''Echelle des Intensités: {\bfI} = non ressenti, {\bfII} = rarement ressenti, {\bfIII} = faiblement ressenti, {\bfIV} = largement ressenti,', ...
            %          '{\bfV} = secousse forte, {\bfVI} = dégâts légers, {\bfVII} = dégâts, {\bfVIII} = dégâts importants, {\bfIX} = destructions, {\bfX} = destructions importantes, ', ...
            %          '{\bfXI} = catastrophe, {\bfXII} = catastrophe généralisée'}, ...
            %        'HorizontalAlignment','left','VerticalAlignment','bottom','FontSize',8);
            %set(gca,'XLim',[0,1],'YLim',[0,1]), axis off

            % Image Postscript + envoi sur l'imprimante + lien symbolique "lasthypo.png"
            print('-dpsc',ftmp);
            disp(sprintf('Graphe: %s créé.',ftmp));
            unix(sprintf('%s -sPAPERSIZE=a4 %s %s',X.PRGM_PS2PDF,ftmp,fgra));
            %unix(sprintf('%s -density 100x100 %s %s',X.PRGM_CONVERT,ftmp,fgra));
            disp(sprintf('Graphe: %s créé.',fgra));
%            if ~test
%                unix(sprintf('lpr %s',ftmp));
%                disp(sprintf('Graphe: %s imprimé.',ftmp));
%				% envoi d'un e-mail à sismo...
%				fid0 = fopen(mtmp,'wt');
%				for ii = 1:length(s_txt)
%					fprintf(fid0,[strrep(strrep(s_txt{ii},'{\bf',''),'}',''),' ']);
%				end
%				fprintf(fid0,'\n\nCommuniqué complet sur ce séisme :\n\nhttp://%s%s/Sismologie/B3/ressentis/%s/%s.pdf \n\n',X.RACINE_URL,X.WEB_RACINE_FTP,pam,fnam);
%				fclose(fid0);
%				unix(sprintf('cat %s >> %s',ftxt,mtmp));
%				unix(sprintf('mail %s -s "Séisme %s MD=%s - B3=%s max à %s" < %s',X.SISMO_EMAIL,dtiso,s_mag,romanx(vmsk(1)),s_gua,mtmp));
%				disp('E-mail envoyé à sismo...');
%            end

            % Lien symbolique sur le dernier ressenti
            if ~test
                [s,w] = unix(sprintf('find %s/ressentis/ -type f -name "*.pdf"|tail -1',pgra));
                ss = sprintf('ln -sf %s %s',deblank(w),f3);
                unix(ss);
                disp(sprintf('Unix: %s',ss));
                [s,w] = unix(sprintf('find %s/traites/ -type f -name "*.txt"|tail -1',pgra));
                ss = sprintf('ln -sf %s %s',deblank(w),f2);
                unix(ss);
                disp(sprintf('Unix: %s',ss));
                ss = sprintf('%s -scale 71x105 %s %s',X.PRGM_CONVERT,f3,f4);
                unix(ss);
                disp(sprintf('Unix: %s',ss));
            end
        end
    end
close
end
end

timelog(rcode,2);
