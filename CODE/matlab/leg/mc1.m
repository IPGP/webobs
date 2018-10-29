function mc(d1,d2)
%MC     Affiche un graphe de Main Courante
%       MC sans argument crée un graphe sur les derniers 30 j.
%       MC(D1) crée un graphe à partir de D1.
%       MC(D1,D2) crée une graphe de D1 à D2.
%

%   Auteurs: F. Beauducel + S. Bazin, OVSG-IPGP
%   Création : 2004-12-31
%   Mise à jour : 2005-04-20

X = readconf;

rcode = 'MC';
timelog(rcode,1)

% Définit le temps présent en TU
tnow = datevec(now + 4/24);

if nargin < 1
    d1 = datenum(tnow) - 30;
end

if nargin < 2
    d2 = datenum(tnow);
end

dman = [2004,11,21,650;
        2004,11,22,600;
        2004,11,23,550;
        2004,11,24,450;
        2004,11,25,500;
        2004,11,26,380;
        2004,11,27,360;
        2004,11,28,240];

% Chargement des fichiers Main Courante nécessaires
tj = (floor(d1):ceil(d2))';
dj = zeros(size(tj,1),3);
th = (tj(1):1/24:tj(end))';
dh = zeros(size(th));

tv1 = datevec(d1);
tv2 = datevec(d2);
mois = tv1(2);
while datenum(tv1(1),mois,1) <= datenum(tv2(1),tv2(2),1)
    tmc = datevec(datenum(tv1(1),mois,1));
    f = sprintf('%s/%s/MC%4d%02d.txt',X.RACINE_WEB,X.MC_PATH_FILE_MAIN_COURANTE,tmc(1:2));
    if exist(f,'file')
       [ss] = flipud(textread(f,'%s','delimiter','\n'));
       disp(sprintf('Fichier: %s importé',f));
       for i = 1:length(ss)
           [dt,hr,ty,x,x,x,x,nb,x,x,x,x,x,x,op,x] = strread(ss{i},'%s%s%s%s%s%s%s%n%s%s%s%s%s%s%s%s%*[^\n]','delimiter','|');
           tt = isodatenum(dt,hr);
           k = find(tj == floor(tt));
           if ~isempty(k)
               switch ty{1}
               case 'TECT'
                   j = 1;
               case {'VOLCEMB','VOLCTECT'}
                   j = 2;
               otherwise
                   j = 3;
               end
               dj(k,j) = dj(k,j) + nb;
           end
           k = find(th == floor(tt*24)/24);
           if ~isempty(k)
               dh(k) = dh(k) + nb;
           end
       end
    end
    mois = mois + 1;
end

% Lecture du dernier événement dépouillé


%===========================================================================
% Correction manuelle 2004-11-21 au 2004-11-28 (main courante pas à jour)
for i = 1:size(dman,1)
    k = find(tj==datenum(dman(i,1:3)));
    if ~isempty(k)
        dj(k,1) = dman(i,4);
    end
end
k = find(th==datenum(2004,11,21,11,0,0));
if ~isempty(k)
    dh(k) = 150;
end

% Exportation du fichier ASCII
f = sprintf('%s/%s/MC.dat',X.RACINE_WEB,X.MC_PATH_FILE_MAIN_COURANTE);
fid = fopen(f,'wt');
fprintf(fid,'# Fichier Main Courante: nombre de séismes par jour\n');
fprintf(fid,'#YYYY-MM-DD TECT VOLC AUTR\n');
for i = 1:length(tj)
    fprintf(fid,'%s-%s-%s %d %d %d\n',datestr(tj(i),'yyyy'),datestr(tj(i),'mm'),datestr(tj(i),'dd'),dj(i,:));
end
fclose(fid);
disp(sprintf('Fichier: %s créé.',f));

fsxy = [15,3];
figure(1),clf
set(gcf,'PaperSize',fsxy,'PaperUnit','inches','PaperPosition',[0,0,fsxy]);
orient portrait
[ax,h1,h2] = plotyy(tj + .5,dj,th + .5/24,dh,'barstack','plot');
pos = get(ax(1),'Position');
set(ax(1),'Position',[pos(1)-.08,pos(2:4)]);
set(ax(2),'Position',[pos(1)-.08,pos(2:4)]);
ylabel('# Journalier')
set(get(ax(2),'YLabel'),'String','# Total Horaire')
set(h2,'Color','c')
colormap(copper)
set(ax(1),'YLim',[0,max(sum(dj'))+1],'YTick',0:100:1000)
set(ax(2),'XTick',[],'YColor','c','YTick',0:50:200);
datetick('x','dd/mm')
set(ax(2),'XLim',get(ax(1),'XLim'));
title(sprintf('Main Courante du %s au %s TU : dernier événement {\\bf%s TU} (%s)',datestr(d1),datestr(d2),datestr(tt),op{1}))
legend(sprintf('TECT = {\\bf%d}',sum(dj(:,1))),sprintf('VOLC = {\\bf%d}',sum(dj(:,2))),sprintf('Autres = {\\bf%d}',sum(dj(:,3))),1)

f = sprintf('%s/%s/MC.png',X.RACINE_WEB,X.MC_PATH_FILE_MAIN_COURANTE);
print(gcf,'-dpng','-painters','-r75',f);
close(1)
disp(sprintf('Graphe: %s créé.',f));

timelog(rcode,2)
