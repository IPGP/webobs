% MONITAR
% graphe automatique rapide de la station Tarissan (e.reader)
%
% utilise les fichiers rappatries par la routine fetch_datalogger.pl sur saussure
%
% Francois Beauducel, decembre 2008

rcode = 'MONITAR';

X = readconf;

pftp = 'TempFlux/TASW/e.reader';
pdat = sprintf('%s/%s',X.RACINE_FTP,pftp);

f_save = sprintf('%s/past/%s_past.mat',X.RACINE_OUTPUT_MATLAB,lower(rcode));
if exist(f_save,'file')
	load(f_save)
else
	t = [];
	d = [];
	old_files = [];
end
s = ls(sprintf('%s/*.dat',pdat));
files = strread(s,'%s');
new_files = setdiff(files,old_files);

for i = 1:length(new_files)
	D = readudbf(new_files{i});
	t = [t;D.time];
	d = [d;D.data];
	disp(sprintf('File: %s imported.',new_files{i}))
end

old_files = files;
save(f_save)
disp(sprintf('File: temporary backup %s updated.',f_save))

% graphes

subplot(311)
plot(t,(d(:,1)-4)*30/16)
datetick('x')
ylabel('Level (m)')
title(sprintf('Last value = %g mA',d(end,1)))

subplot(312)
plot(t,d(:,2))
datetick('x')
ylabel('CTN1 (kOhm)')
title(sprintf('Last value = %g kOhm',d(end,2)))

subplot(313)
plot(t,d(:,3))
datetick('x')
ylabel('CTN2 (kOhm)')
title(sprintf('Last value = %g kOhm',d(end,3)))
xlabel(sprintf('%s - %s',datestr(t(1)),datestr(t(end))))

f = sprintf('%s/graph.png',pdat);
print(f,'-dpng','-r300')
disp(sprintf('Graph: %s updated.',f))

xlim = now-[1,0];
k = find(t>=xlim(1) & t<xlim(2));

subplot(311)
plot(t(k),(d(k,1)-4)*30/16,'LineWidth',2)
datetick('x')
ylabel('Level (m)')
title(sprintf('Last value = %g mA',d(end,1)))

subplot(312)
plot(t(k),d(k,2),'LineWidth',2)
datetick('x')
ylabel('CTN1 (kOhm)')
title(sprintf('Last value = %g kOhm',d(end,2)))

subplot(313)
plot(t(k),d(k,3),'LineWidth',2)
datetick('x')
ylabel('CTN2 (kOhm)')
title(sprintf('Last value = %g kOhm',d(end,3)))
xlabel(sprintf('%s - %s',datestr(xlim(1)),datestr(xlim(2))))

f = sprintf('%s/graph24h.png',pdat);
print(f,'-dpng','-r300')
disp(sprintf('Graph: %s updated.',f))

