function [nr,na,nt,TT] = tele(S,ixy);
%TELE   Trace les liaisons télémétrées de stations OVSG.
%       TELE(S) trace les liaisons point à point des stations S sur le graphe 
%       courant (éventuellement via un relais) et renvoie le nombre de relais 
%       trouvé pour ces stations.
%       Utilise le fichier de configuration "typeTransmission.conf" et les paramètres
%	de transmission dans chaque fiche de station

%   Auteurs: F. Beauducel + C. Anténor-Habazac, OVSG-IPGP
%   Création : 2002-06-24
%   Mise à jour : 2007-09-16

X = readconf;

f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.STATIONS_FILE_TELE);
[typ,nom,sty] = textread(f,'%q%q%q','delimiter','|','commentstyle','shell');
T = {
disp(sprintf('Fichier: %s importé.',f));

ST = readst('',{'G','M'});
stcoo = [ST.utm,ST.geo,ST.wgs];

ix = ixy(1);
iy = ixy(2);

n = 0;
nt = 0;
ka = 0;
kt = [];
for i = 1:length(S)
    k = find(strcmp(ST.cod,S(i)));
    if ~isempty(k) & ~isempty(ST.tra(k),',')
		[t,r] = strread(ST.tra{k},'%s%s','delimiter',',');
		if t > 0 & ~isempty(r)
			rr = strread(r,'%s','delimiter','|');
			na = na + 1;
			nt = nt + length(rr) - 1;
			if length(rr) > 1
				n = n + length(rr) - 1;
			end
			
        k0 = find(strcmp(ST,sta{i})); % station
        k1 = find(strcmp(ST,acq{i})); % acquisition
        k2 = find(strcmp(ST,rel1{i})); % relais 1
        k3 = find(strcmp(ST,rel2{i})); % relais 2
        k4 = find(strcmp(ST,rel3{i})); % relais 3
        kk = [k0 k2 k3 k4 k1];
        
        plot(stcoo(kk,ix),stcoo(kk,iy),'LineStyle',T{typ(i)}{3},'Color',T{typ(i)}{4},'LineWidth',.1);
        if isempty(kt)
            kt = typ(i);
        else
            if isempty(find(kt==typ(i))), kt = [kt,typ(i)]; end
        end
        plot(stcoo([k2 k3 k4],ix),stcoo([k2 k3 k4],iy),'LineStyle','none','Marker','p', ...
            'MarkerEdgeColor','k','MarkerSize',6,'MarkerFaceColor',[1 1 1]);
        if isempty(find(k1==ka))
            plot(stcoo(k1,ix),stcoo(k1,iy),'LineStyle','none','Marker','p', ...
                'MarkerEdgeColor','k','MarkerSize',12);
            ka = [ka,k1];
        end
    end
end
nr = n;
TT = T(kt);
