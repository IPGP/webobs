%X = readconf;
%f = sprintf('%s/%s',X.RACINE_FICHIERS_CONFIGURATION,X.FILE_VOIES_SEFRAN);
%[sfr,sfg] = textread(f,'%s%n','commentstyle','shell');
seuil = 50;
%[t,d] = loadsuds('/home/ftp/Sismologie/Signaux/Seisme2004/0406/04023753.GUA');
dd = mavr(abs(d-repmat(mean(d),[size(d,1),1])),50);
dc = zeros(size(sfr,1),4)*NaN;
for i = 1:length(sfr)
    k = find(dd(:,i)>seuil);
    if ~isempty(k)
        dc(i,1) = t(k(i));
        dc(i,2) = diff(t(k([1,end])))*86400;
    end
    k = find(diff(dd(:,i))>2);
    if ~isempty(k)
        dc(i,3) = t(k(i));
        dc(i,4) = diff(t(k([1,end])))*86400;
    end
end
[x,is] = sort(dc(:,3));
for i = 1:length(sfr)
    if ~isnan(dc(is(i),1))
        disp(sprintf('%s %0.3f - %1.0f s | %0.3f - %1.0f s',sfr{is(i)},60*(dc(is(i),1)*1440 - floor(dc(is(i),1)*1440)),dc(is(i),2),60*(dc(is(i),3)*1440 - floor(dc(is(i),3)*1440)),dc(is(i),4)))
    end
end
plot(t,dd), datetick('x')
