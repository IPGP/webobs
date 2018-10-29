function mc(d1,d2)
%MC     Affiche un graphe de Main Courante
%       MC sans argument crée un graphe sur les derniers 30 j.
%       MC(D1) crée un graphe à partir de D1.
%       MC(D1,D2) crée une graphe de D1 à D2.
%

%   Auteurs: F. Beauducel + S. Bazin, OVSG-IPGP
%   Création : 2004-12-31
%   Mise à jour : 2009-10-09

X = readconf;

rcode = 'MC';
timelog(rcode,1)

% Définit le temps présent en TU
tnow = datevec(ceil(now - str2double(X.MATLAB_SERVER_UTC)/24));

if nargin < 1
    d1 = datenum(tnow) - 181;
end

if nargin < 2
    d2 = datenum(tnow);
end

pmc = X.MC_RACINE;

% Chargement des fichiers Main Courante nécessaires
t = [];
d = [];

tv1 = datevec(d1);
tv2 = datevec(d2);
mois = tv1(2);
while datenum(tv1(1),mois,1) <= datenum(tv2(1),tv2(2),1)
    tmc = datevec(datenum(tv1(1),mois,1));
    f = sprintf('%s/%s/MC%4d%02d.txt',pmc,X.MC_PATH_FILES,tmc(1:2));
    if exist(f,'file')
       [id,dd,hh,ty,x,x,x,x,nb]=textread(f,'%s%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|');
       dte = [str2double(split(dd,'-')),str2double(split(hh,':'))];
       nb = str2double(nb);
       disp(sprintf('Fichier: %s importé',f));
       [ttt,j] = sort(datenum(dte));
       ty = ty(j);
       t = [t;ttt];
       ddd = [nb(j),zeros(size(ttt))];
       k = find(strcmp(ty,'TECT'));
       ddd(k,2) = ones(size(k))*1;
       k = find(strcmp(ty,'VOLCTECT') | strcmp(ty,'VOLCEMB') | strcmp(ty,'VOLCLP') | strcmp(ty,'TREMOR'));
       ddd(k,2) = ones(size(k))*2;
       d = [d;ddd];
    end
    mois = mois + 1;
end

% Calcul des histogrammes
k0 = find(d(:,2)==0);
k1 = find(d(:,2)==1);
k2 = find(d(:,2)==2);
% journalier
tj = (d1:d2)';
dj = [histw(t(k1),d(k1,1),tj),histw(t(k2),d(k2,1),tj),histw(t(k0),d(k0,1),tj)];
% horaire
th = (tj(1):1/24:tj(end))';
dh = histw(t,d(:,1),th);

save('/tmp/mc.mat');

% Exportation du fichier ASCII
f = '/tmp/MC.dat';
fid = fopen(f,'wt');
fprintf(fid,'# Fichier Main Courante: nombre de séismes par jour depuis le %s\n',datestr(tj(1)));
fprintf(fid,'#AAAA-MM-DD hh:mm NJ TECT VOLC AUTR\n');
for i = 1:length(tj)
    fprintf(fid,'%4d-%02d-%02d %02d:%02d:%02.0f %d %d %d %d\n',datevec(tj(i)),round(tj(i)-tj(1)),dj(i,:));
end
fclose(fid);
unix(sprintf('cp -f %s %s/MC.dat',f,pmc));
disp(sprintf('Fichier: %s créé.',f));

% Figures
%figure(1), clf, set(gcf,'PaperSize',[10.5,11],'Units','inches'), orient tall
figure(1), clf, set(gcf,'PaperSize',[10.5,11]*2.54); orient tall

% graphe sur 10 jours
subplot(4,1,1)
dt = 10;
d10 = d2 - dt;
kj = find(tj >= d10);
kh = find(th >= d10);
pos = get(gca,'Position');
%set(gca,'Position',[.06,pos(2)+.05,.88,pos(4)],'YLim',[0,max(sum(dj'))+1],'FontSize',8)
set(gca,'Position',[.05,pos(2)+.05,.9,pos(4)])
h1 = barstack(tj(kj) + .5,dj(kj,:));
hold on
h2 = plot(th(kh) + .5/24,dh(kh),'c','LineWidth',2);
hold off
colormap(copper)
datetick('x',19)
xlim = get(gca,'XLim');
set(gca,'XLim',[d10,d2],'TickDir','out','TickLength',[0.005,0.01],'YLim',[0,max(sum(dj(kj,:)'))+1],'FontSize',8)
ylabel('# Journalier / Horaire')
title(sprintf('Dernier événement main courante OVSG-IPGP = {\\bf%s TU}',datestr(t(end),0)))
legend('Total Horaire',sprintf('TECT = {\\bf%d} (%d,%d,%d)',sum(dj(kj,1)),dj(end-[3,2,1],1)), ...
                       sprintf('VOLC = {\\bf%d} (%d,%d,%d)',sum(dj(kj,2)),dj(end-[3,2,1],2)), ...
                       sprintf('Autres = {\\bf%d} (%d,%d,%d)',sum(dj(kj,3)),dj(end-[3,2,1],3)),2)


% graphe sur 6 mois
subplot(4,1,2)
pos = get(gca,'Position');
%set(gca,'Position',[.06,pos(2)+.05,.88,pos(4)],'YLim',[0,max(sum(dj'))+1],'FontSize',8)
set(gca,'Position',[.05,pos(2)+.05,.9,pos(4)])
h1 = barstack(tj + .5,dj);
hold on
h2 = plot(th + .5/24,dh,'c');
hold off
colormap(copper)
datetick('x','mmmyyyy')
xlim = get(gca,'XLim');
set(gca,'XLim',[d1,d2],'TickDir','out','TickLength',[0.005,0.01],'YLim',[0,max(sum(dj'))+1],'FontSize',8)
ylabel('# Journalier / Horaire')
legend('Total Horaire',sprintf('TECT = {\\bf%d}',sum(dj(:,1))), ...
                       sprintf('VOLC = {\\bf%d}',sum(dj(:,2))), ...
                       sprintf('Autres = {\\bf%d}',sum(dj(:,3))),2)


% échelle semilog
%t0 = datenum(2004,11,21,11,41,0);
t0 = d1;
map = copper(3);
tjs = tj(1:(end-1)) - d2;
djs = dj(1:(end-1),:);
subplot(4,1,3:4);
pos = get(gca,'Position');
set(gca,'Position',[.05,pos(2),.9,pos(4)+.05],'FontSize',8)
plot(tjs,djs(:,1),'Color',map(1,:),'LineWidth',2), hold on
%plot(tj - t0,mavr(dj(:,1),10),'-','LineWidth',2)
%plot(th - t0,dh,'r')
plot(tjs,djs(:,2),'Color',map(2,:),'LineWidth',2)
plot(tjs,djs(:,3),'Color',map(3,:))
hold off
%ylim = get(gca,'YLim');
%set(gca,'XScale','linear','YScale','log','YLim',[1,ylim(2)])
set(gca,'XLim',[d1,d2] - d2)
xlabel(sprintf('Nombre de jours jusqu''au %s TU',datestr(d2,0)))
ylabel('Nombre d''événéments')
grid on
title(sprintf('Main Courante OVSG du %s au %s TU',datestr(d1,0),datestr(d2,0)))
%legend('Journalier','Journalier filtré (10 j)','Horaire')
legend('TECT','VOLC','Autres',2)

f = '/tmp/MC.png';
f2 = '/tmp/MC.jpg';
matpad('WEBOBS / FB, OVSG-IPGP',0,[],f);
print(gcf,'-dpng','-painters','-r100',f);
%close(1)
unix(sprintf('cp -f %s %s',f,pmc));
unix(sprintf('%s -scale 100x105 %s %s',X.PRGM_CONVERT,f,f2));
unix(sprintf('cp -f %s %s',f2,pmc));
disp(sprintf('Graphe: %s et icône .jpg créés.',f));

timelog(rcode,2)
