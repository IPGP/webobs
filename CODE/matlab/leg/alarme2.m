function alm=alarme2(t,d,s);
%ALARME Alarme sur les signaux du SEFRAN2
%       ALARME(T,D,S) traite les signaux sismiques D(T) des stations S.
%
%   Auteurs: F. Beauducel, OVSG-IPGP
%   Création : 2004-08-12
%   Mise à jour : 2009-03-30

alarm_nb = 3;                       % nombre minimum de stations
alarm_amp_filtre = 50;              % durée du filtre (en échantillons)
alarm_amp_seuil = 0.25;             % seuil d'amplitude saturation
alarm_depart_seuil = 0.01;            % seuil d'amplitude départ
alarm_amp_duree = 150;              % durée de saturation amplitude (en échantillons)
samp = diff(t(1:2));

disp('Traitement des alarmes...');
alm = zeros(size(d,2),3);
amp = mavr(abs(d - repmat(mean(d),[length(d),1])),alarm_amp_filtre);
% Efface les premiers échantillons (mal filtrés par MAVR)
amp(1:alarm_amp_filtre,:) = [];
t(1:alarm_amp_filtre,:) = [];

for i = 1:length(s)
    kd = find(amp(:,i) >= alarm_depart_seuil);
    if ~isempty(kd)
        alm(i,1) = t(kd(1));
        disp(sprintf('* %s TU : %s détection phase.',datestr(t(kd(1))),s{i}));
    end
    ks = find(amp(:,i) >= alarm_amp_seuil);
    if ~isempty(ks)
        alm(i,2) = t(ks(1));
        alm(i,3) = length(ks)*samp*86400;
        disp(sprintf('* %s TU : %s amplitude > %g durant %1.0f s',datestr(t(ks(1))),s{i},alarm_amp_seuil,alm(i,3)));
    end
end
nbs = length(find(alm(:,2)));
if nbs >= alarm_nb
    disp(sprintf('*** ALARME : %d stations au dessus du seuil durant %1.0f s max. ***',nbs,max(alm(:,3))));
    sts = '';
    [ta,is] = sort(alm(:,1));
    kf = find(alm(is,1));
    for i = 1:length(s)
        ii = is(i);
        if alm(ii,1)
            if alm(ii,2)
                sts = sprintf('%s x%s',sts,s{ii});
            else
                sts = sprintf('%s %s',sts,s{ii});
            end
        end
    end
     
    msg = sprintf('ALARME %s TU :%s',datestr(alm(is(kf(1)),1)),sts);
    alerte(msg);
end
