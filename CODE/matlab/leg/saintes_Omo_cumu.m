function D = saintes(d1,d2);
%SAINTES Construit plusieurs graphes sur les Saintes à partir des données sismo
%

%   Auteurs: F. Beauducel, S. Bazin, A. Nercessian, OVSG-IPGP
%   Création : 2005-08-19
%   Mise à jour : 2006-07-24

X = readconf;

rcode = 'SAINTES';
timelog(rcode,1)

% Définit le temps présent en TU
tnow = datevec(ceil(now + 4/24));
t0 = datenum(2004,11,21,11,41,0);
t1 = datenum(2005,2,14,18,5,0);

if nargin < 1
    d1 = t0;
end

if nargin < 2
    d2 = datenum(tnow);
end

pdon = sprintf('%s/Phenom/Seismes/Les_Saintes',X.RACINE_FTP);
xylim = [-61.75,-61.333,15.583,16];
xy0 = [-61.538,15.749,14.5];						% Hypocentre du choc principal
map = jet(16);
mks = 5;
dpi = 150;
degkm = 6370*pi/180;                                % valeur du degré (en km)


% ==========================================================
% Figure Main Courante - Loi d'Omori
% ==========================================================
% Chargement des fichiers Main Courante nécessaires
t = [];
d = [];

tv1 = datevec(d1);
tv2 = datevec(d2);
mois = tv1(2);
while datenum(tv1(1),mois,1) <= datenum(tv2(1),tv2(2),1)
    tmc = datevec(datenum(tv1(1),mois,1));
    f = sprintf('%s/%s/MC%4d%02d.txt',X.MC_RACINE,X.MC_PATH_FILES,tmc(1:2));
    if exist(f,'file')
       [id,yy,mm,dd,hh,nn,ss,ty,x,x,x,x,nb,x,st,x,x,x,x,x,co]=textread(f,'%n%n-%n-%n%n:%n:%n%s%s%s%s%s%n%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|');
       disp(sprintf('Fichier: %s importé',f));
       [ttt,j] = sort(datenum(yy,mm,dd,hh,nn,ss));
       ty = ty(j);  st = st(j); co = co(j);
       t = [t;ttt];
       ddd = [nb(j),zeros(size(ttt))];
       %k = find(strcmp(ty,'TECT'));
       k = find(strcmp(ty,'TECT') & (strcmp(st,'TBGZ') | strcmp(st,'MAGZ') | ~cellfun('isempty',{regexpi(co,'Saintes')})));
       ddd(k,2) = ones(size(k))*1;
       k = find(strcmp(ty,'VOLCTECT') | strcmp(ty,'VOLCEMB') | strcmp(ty,'VOLCLP') | strcmp(ty,'TREMOR'));
       ddd(k,2) = ones(size(k))*2;
       d = [d;ddd];
    end
    mois = mois + 1;
end

% on ne garde que les données "valides" (dans l'intervalle d1,d2)
k = find(t<d1 | t>d2);
t(k) = [];
d(k,:) = [];

% Calcul des histogrammes
k0 = find(d(:,2)==0);
k1 = find(d(:,2)==1);
k2 = find(d(:,2)==2);
% journalier
tj = (d1:(d2+1))';
dj = [histw(t(k1),d(k1,1),tj),histw(t(k2),d(k2,1),tj),histw(t(k0),d(k0,1),tj)];
% horaire
th = (tj(1):1/24:tj(end))';
dh = histw(t(k1),d(k1,1),th);
% mensuel
tm = (tj(1):30:tj(end))';
dm = histw(t(k1),d(k1,1),tm);

% Exportation du fichier ASCII: événements
f = sprintf('%s/%s_MC.dat',pdon,rcode);
fid = fopen(f,'wt');
fprintf(fid,'# Fichier Main Courante: date et heures des événements depuis le %s\n',datestr(tj(1)));
fprintf(fid,'#AAAA-MM-DD hh:mm:ss SAINTES\n');
for i = 1:length(k1)
    fprintf(fid,'%4d-%02d-%02d %02d:%02d:%02.0f %d\n',datevec(t(k1(i))),d(k1(i),1));
end
fclose(fid);
disp(sprintf('Fichier: %s créé.',f));

% Exportation du fichier ASCII: horaire
f = sprintf('%s/%s_MC_heure.dat',pdon,rcode);
fid = fopen(f,'wt');
fprintf(fid,'# Fichier Main Courante: nombre de séismes par heure depuis le %s\n',datestr(tj(1)));
fprintf(fid,'#AAAA-MM-DD hh:mm:ss SAINTES\n');
for i = 1:length(th)
    fprintf(fid,'%4d-%02d-%02d %02d:%02d:%02.0f %d\n',datevec(th(i)),dh(i));
end
fclose(fid);
disp(sprintf('Fichier: %s créé.',f));

% Exportation du fichier ASCII: journalier
f = sprintf('%s/%s_MC_jour.dat',pdon,rcode);
fid = fopen(f,'wt');
fprintf(fid,'# Fichier Main Courante: nombre de séismes par jour depuis le %s\n',datestr(tj(1)));
fprintf(fid,'#AAAA-MM-DD hh:mm:ss NJ SAINTES VOLC AUTR\n');
for i = 1:length(tj)
    fprintf(fid,'%4d-%02d-%02d %02d:%02d:%02.0f %d %d %d %d\n',datevec(tj(i)),round(tj(i)-tj(1)),dj(i,:));
end
fclose(fid);
disp(sprintf('Fichier: %s créé.',f));

% Figure échelles linéaire et log
figure(1), clf, set(gcf,'PaperSize',[10.5,11]), orient tall

% échelle linéaire
subplot(4,1,1)
h1 = barstack(tj + .5,dj);
%hold on
%h2 = plot(th + .5/24,dh);
%hold off
pos = get(gca,'Position');
set(gca,'Position',[.06,pos(2)+.05,.88,pos(4)],'YLim',[0,max(sum(dj'))+1],'YTick',0:500:2500,'FontSize',8)
%ylabel('# Journalier / Horaire*10')
ylabel('# Journalier')
colormap(copper)
datetick('x','mmmyyyy')
xlim = get(gca,'XLim');
set(gca,'XLim',[xlim(1),t(end)],'TickDir','out','TickLength',[0.005,0.01])
title(sprintf('Main Courante OVSG : {\\bf%d , %d/j} - Dernier événement {\\bf%s TU}',sum(dj(end-2,:)),sum(dj(end-1,:)),datestr(t(end))))
%legend('Total Horaire x10',sprintf('TECT = {\\bf%d}',sum(dj(:,1))),sprintf('VOLC = {\\bf%d}',sum(dj(:,2))),sprintf('Autres = {\\bf%d}',sum(dj(:,3))),1)
legend(sprintf('SAINTES = {\\bf%d}',sum(dj(:,1))),sprintf('VOLC = {\\bf%d}',sum(dj(:,2))),sprintf('Autres = {\\bf%d}',sum(dj(:,3))),1)

% échelle semilog
subplot(4,2,[3,5,7]);
pos = get(gca,'Position');
plot(tj - t0,dj(:,1),'LineWidth',.1), hold on
plot(tj - t0,mavr(dj(:,1),10),'-m','LineWidth',1)
%plot(th - t0,dh,'r')
hold off
set(gca,'Position',[pos(1)-0.08,pos(2),pos(3)+0.13,pos(4)])
set(gca,'XScale','linear','YScale','log','FontSize',8,'YLim',[1,1e4])
xlabel(sprintf('Temps écoulé depuis le %s (en jours)',datestr(t0)))
ylabel('Nombre d''événéments')
grid on
%legend('Journalier','Journalier filtré (10 j)','Horaire')
legend('Journalier','Journalier filtré (10 j)')

% Loi Omori 21/11/2004
% subplot(8,2,6:2:10)
% plot(th - t0,dh*24,'.r','MarkerSize',3)
% hold on
% plot(tj - t0 + 1,dj(:,1),'LineWidth',.1)
% plot(tm - t0,dm/30,'-','LineWidth',1,'Color',[0,.7,0])
% hold off
% set(gca,'XScale','log','YScale','log','FontSize',8,'XLim',[1e-2,1e3],'YLim',[1,1e4])
% xlabel(sprintf('Temps écoulé depuis le %s (en jours)',datestr(t0)))
% ylabel('Nombre d''événéments par jour')
% legend('Journalier','Horaire','Mensuel',3)
% title(sprintf('Loi d''Omori depuis le %s',datestr(t0)))

subplot(8,2,6:2:10)
plot(th - t0,cumsum(dh),'LineWidth',3)
% hold on
% plot(tj - t1 + 1,dj(:,1),'LineWidth',.1)
% plot(tm - t1,dm/30,'-','LineWidth',1,'Color',[0,.7,0])
% hold off
set(gca,'XScale','log','YScale','log','FontSize',8)
xlabel(sprintf('Temps écoulé depuis le %s (en jours)',datestr(t1)))
ylabel('Nombre d''événéments cumulé')
title('Loi d''Omori')


% Loi Omori 14/02/2005
tm = (t1:30:tj(end))';
dm = histw(t,d(:,1),tm);

subplot(8,2,12:2:16)
plot(th - t1,dh*24,'.r','MarkerSize',3)
hold on
plot(tj - t1 + 1,dj(:,1),'LineWidth',.1)
plot(tm - t1,dm/30,'-','LineWidth',1,'Color',[0,.7,0])
hold off
set(gca,'XScale','log','YScale','log','FontSize',8,'XLim',[1e-2,1e3],'YLim',[1,1e4])
xlabel(sprintf('Temps écoulé depuis le %s (en jours)',datestr(t1)))
ylabel('Nombre d''événéments')
legend('Journalier','Horaire','Mensuel',3)
title('Loi d''Omori')



f = sprintf('%s/%s_OVSG_00',pdon,rcode);
matpad('OVSG-IPGP - [FB]',0,[],f);
print(gcf,'-dpsc',sprintf('%s.ps',f));
unix(sprintf('%s -density %d %s.ps %s.png',X.PRGM_CONVERT,dpi,f,f));
unix(sprintf('%s -scale 100x105 %s.png %s.jpg',X.PRGM_CONVERT,f,f));
%print(gcf,'-dpng','-painters','-r100',sprintf('%s.png',f));
close(1)
disp(sprintf('Graphe: %s créé (ps + png).',f));


% ==========================================================
% Figures Hypocentres - Gutenberg-Richter
% ==========================================================

% chargement des hypocentres (2004 - présent)
load(sprintf('%s/past/HYPO_past.mat',X.RACINE_OUTPUT_MATLAB),'DH')

% sélection des séismes dans la zone des Saintes
k = find(DH.lat > xylim(3) & DH.lat < xylim(4) & DH.lon > xylim(1) & DH.lon < xylim(2));
tlim = [floor(DH.tps(k(1))),d2];
kfs = k(find(DH.tps(k) < t0));
k21 = k(find(DH.tps(k) > t0));
k14 = k(find(DH.tps(k) > t0 & DH.tps(k) < t1));
kas = k(find(DH.tps(k) > t1));

% histogramme des magnitudes
figure(1), clf, orient tall
dm = (1:6)';
dm2 = (1:.5:6)';

subplot(211)
n2 = hist(DH.mag(k21),dm2)';
n1 = hist(DH.mag(k21),dm)';
bar(dm,n1,'w'), hold on, bar(dm2,n2), hold off
text(dm,n1+40,cellstr(num2str(n1)),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',10,'FontWeight','bold')
text(dm2,n2,cellstr(num2str(n2)),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8)
xlabel('Magnitudes')
ylabel('Nombre d''événements')
title(sprintf('Les Saintes: Histogramme des magnitudes du %s aux %s',datestr(t0),datestr(tlim(2))),'FontWeight','bold')

% Loi Gutenberg-Richter et B-value
subplot(212)
mgr = (1:.25:7)';
ngr = flipud(cumsum(flipud(histc(DH.mag(k21),mgr))));
kgr = find(mgr >= 2.5 & ngr > 0);
pgr = polyfit(mgr(kgr),log10(ngr(kgr)),1);
semilogy(mgr,ngr,'s-')
hold on,plot(mgr([1,end]),10.^polyval(pgr,mgr([1,end])),'--k'),hold off
grid on
text(2,1,sprintf('{\\itPente (MD>=2.5) = %1.2f}',pgr(1)),'FontSize',14,'VerticalAlignment','bottom')
xlabel('Magnitudes (MD)')
ylabel('Nombre d''événements')
title(sprintf('Les Saintes: Loi Gutenberg-Richter du %s au %s',datestr(t0),datestr(tlim(2))),'FontWeight','bold')

f = sprintf('%s/%s_OVSG_01',pdon,rcode);
matpad('OVSG-IPGP - [FB]',0,[],f);
print(gcf,'-dpsc',sprintf('%s.ps',f));
unix(sprintf('%s -density %d %s.ps %s.png',X.PRGM_CONVERT,dpi,f,f));
unix(sprintf('%s -scale 100x105 %s.png %s.jpg',X.PRGM_CONVERT,f,f));
close(1)
disp(sprintf('Graphe: %s créé (ps + png).',f));


% Evolution temporelle des magnitudes 
figure(1),clf, orient tall

subplot(10,1,1), extaxes
t = t0-floor(t0)+(tlim(1):tlim(2))';
n = histc(DH.tps(k),t);
bar(t-t0,n,'histc')
ylabel('Nombre/jour')
title(sprintf('Les Saintes: Evolution temporelle séismes localisés du %s au %s',datestr(tlim(1)),datestr(tlim(2))),'FontWeight','bold')
set(gca,'XLim',tlim-t0,'FontSize',8)

subplot(10,1,2), extaxes
[c,ia,ib] = intersect(t,tj);
plot(tj(ib)-t0,100*n(ia)./dj(ib,1))
ylabel('% localisés')
set(gca,'XLim',tlim-t0,'FontSize',8)

subplot(10,1,3:5), extaxes
h = plotc(DH.tps(k)-t0,DH.mag(k),DH.mag(k),map,[1,4]);
set(h,'MarkerSize',mks)
ylabel('Magnitudes')
set(gca,'XLim',tlim-t0,'FontSize',8)

subplot(10,1,6:7), extaxes
h = plotc(DH.tps(k)-t0,-DH.dep(k),DH.mag(k),map,[1,4]);
set(h,'MarkerSize',mks)
ylabel('Prof. (km)')
set(gca,'XLim',tlim-t0,'FontSize',8)

subplot(10,1,8:10), extaxes
pros = [xy0(1:2),3*pi/4];
oxy = [DH.lon(k)' - pros(1);DH.lat(k)' - pros(2)];	% coordonnées XY avec nouvelle origine
pxy = degkm*[cos(pros(3)) sin(pros(3));-sin(pros(3)) cos(pros(3))]*oxy;	% coordonnées XY après rotation
h = plotc(DH.tps(k)-t0,pxy(1,:),DH.mag(k),map,[1,4]);
set(h,'MarkerSize',mks)
ylabel('Proj. F. Roseau (km)')
set(gca,'XLim',tlim-t0,'FontSize',8)

%subplot(20,1,20), extaxes
bv = bvalue(DH.mag(k21),2,1,4);
%plot(tlim-t0,bv(1)*([1,1]),'--k','LineWidth',.1)
%text(tlim(1)-t0,bv(1),sprintf(' Total depuis 21/11/2004 = %1.2f',bv(1)),'VerticalAlignment','bottom','FontSize',6)
%hold on
dbv = 200;
tbv = ((tlim(1)+dbv):tlim(2))';
bbv = nan*zeros([length(tbv),2]);
for i = 1:length(tbv)
	%kbv = k(find(DH.tps(k)>(tbv(i)-dbv) & DH.tps(k)<tbv(i)));
	kbv = k(find(DH.tps(k)<tbv(i)));
	bbv(i,:) = bvalue(DH.mag(kbv),2,1,4);
end
%plot(tbv-t0,bbv(:,1),tbv-t0,[bbv(:,1)+bbv(:,2),bbv(:,1)-bbv(:,2)],'.','MarkerSize',.1)
%plot(tbv-t0,bbv(:,1),'.','MarkerSize',.1)
%hold off
%set(gca,'XLim',tlim-t0,'FontSize',8)
%ylabel('B-Values')

xlabel(sprintf('Jours à partir du %s',datestr(t0)));


f = sprintf('%s/%s_OVSG_02',pdon,rcode);
matpad('OVSG-IPGP - [FB+AN]',0,[],f);
print(gcf,'-dpsc',sprintf('%s.ps',f));
unix(sprintf('%s -density %d %s.ps %s.png',X.PRGM_CONVERT,dpi,f,f));
unix(sprintf('%s -scale 100x105 %s.png %s.jpg',X.PRGM_CONVERT,f,f));
close(1)
disp(sprintf('Graphe: %s créé (ps + png).',f));


% Cartes
figure(1), clf, orient tall

subplot(221)
h = plotc(DH.lon(kfs),DH.lat(kfs),DH.mag(kfs),map,[1,4]);
xlabel('Longitudes (°E)')
ylabel('Latitudes (°N)')
title(sprintf('Les Saintes: du %s au %s',datestr(tlim(1)),datestr(t0)),'FontWeight','bold','FontSize',8)
set(gca,'XLim',xylim(1:2),'YLim',xylim(3:4),'FontSize',8)
set(h,'MarkerSize',10)

subplot(222)
h = plotc(DH.lon(k14),DH.lat(k14),DH.mag(k14),map,[1,4]);
xlabel('Longitudes (°E)')
ylabel('Latitudes (°N)')
title(sprintf('Les Saintes: du %s au %s',datestr(t0),datestr(t1)),'FontWeight','bold','FontSize',8)
set(h,'MarkerSize',10)
set(gca,'XLim',xylim(1:2),'YLim',xylim(3:4),'FontSize',8)

subplot(223)
h = plotc(DH.lon(kas),DH.lat(kas),DH.mag(kas),map,[1,4]);
xlabel('Longitudes (°E)')
ylabel('Latitudes (°N)')
title(sprintf('Les Saintes: du %s au %s',datestr(t1),datestr(tlim(2))),'FontWeight','bold','FontSize',8)
set(gca,'XLim',xylim(1:2),'YLim',xylim(3:4),'FontSize',8)
set(h,'MarkerSize',10)

subplot(224)
h = plotc(DH.lon(k),DH.lat(k),DH.mag(k),map,[1,4]);
xlabel('Longitudes (°E)')
ylabel('Latitudes (°N)')
title(sprintf('Les Saintes: du %s au %s',datestr(tlim(1)),datestr(tlim(2))),'FontWeight','bold','FontSize',8)
set(h,'MarkerSize',10)
set(gca,'XLim',xylim(1:2),'YLim',xylim(3:4),'FontSize',8)

f = sprintf('%s/%s_OVSG_03',pdon,rcode);
matpad('OVSG-IPGP - [FB]',0,[],f);
print(gcf,'-dpsc',sprintf('%s.ps',f));
unix(sprintf('%s -density %d %s.ps %s.png',X.PRGM_CONVERT,dpi,f,f));
unix(sprintf('%s -scale 100x105 %s.png %s.jpg',X.PRGM_CONVERT,f,f));
close(1)
disp(sprintf('Graphe: %s créé (ps + png).',f));


% Cartelettes
figure(1), clf, orient tall
mn = [4,3];
sz = prod(mn);
for i = 1:sz
    subplot(mn(1),mn(2),i)
    tt = [i-1,i]*(tlim(2)-floor(t0))/sz + t0;
    kk = k(find(DH.tps(k) > tt(1) & DH.tps(k) < tt(2)));
    h = plotc(DH.lon(kk),DH.lat(kk),DH.mag(kk),map,[1,4]);
	hold on
	plot(xy0([1,1]),xylim(3:4),':k')
	plot(xylim(1:2),xy0([2,2]),':k')
	hold off
    set(h,'MarkerSize',10)
    set(gca,'XLim',xylim(1:2),'YLim',xylim(3:4),'FontSize',6)
    title({datestr(tt(1),0),datestr(tt(2),0)},'FontSize',8)
end

f = sprintf('%s/%s_OVSG_04',pdon,rcode);
matpad('OVSG-IPGP - [FB]',0,[],f);
print(gcf,'-dpsc',sprintf('%s.ps',f));
unix(sprintf('%s -density %d %s.ps %s.png',X.PRGM_CONVERT,dpi,f,f));
unix(sprintf('%s -scale 100x105 %s.png %s.jpg',X.PRGM_CONVERT,f,f));
close(1)
disp(sprintf('Graphe: %s créé (ps + png).',f));

save(sprintf('%s/past/SAINTES_past.mat',X.RACINE_OUTPUT_MATLAB))


timelog(rcode,2)

if nargout
	D.mc = [tj,dj];
	D.tps = DH.tps(k);
	D.mag= DH.mag(k);
	D.lon = DH.lon(k);
	D.lat = DH.lat(k);
	D.dep = DH.dep(k);
	D.loc = [tj(ib),100*n(ia)./dj(ib,1)];
	D.tbv = tbv;
	D.bbv = bbv;
end
