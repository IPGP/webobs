% MONITAR
% Complementary graphs of Tarissan pit monitoring data
%
% Authors: Francois Beauducel & Dominique Gibert
% Created: 2008-12-23
% Modified: 2009-04-23

rcode = 'MONITAR';

X = readconf;

pdat = sprintf('%s/TempFlux/TASW',X.RACINE_FTP);
gris = .5*[1,1,1];

% load the saved Matlab file from WEBOBS routine process 
% (includes all METEO data from Piton Sanner)
f = sprintf('%s/past/%s.mat',X.RACINE_OUTPUT_MATLAB,rcode);
load(f)
fprintf('File: %s loaded.\n',f);

NFilter = 20;   % length of filtering in mn, let = 0 for no filtering
NUnits = 60;    % Number of seconds in one minute
dt = 2;         % sampling interval in seconds
	
t_pb = [datenum(2008,12,15,11,56,0),datenum(2008,12,15,12,32,0);
	datenum(2008,12,11,12,45,0),datenum(2008,12,13,15,22,0);
	datenum(2008,12,27,07,45,0),datenum(2008,12,28,22,0,0);
	datenum(2009,01,01,11,0,0),datenum(2009,01,16,16,25,0);
	];

% replacing unvalid level data by NaN
for i = 1:size(t_pb,1)
	k = find(t>=t_pb(i,1) & t<=t_pb(i,2));
	d(k,1) = NaN;
end

% selecting all valid data
tdeb = datenum(2008,12,8,13,52,0);
k = find(t>=tdeb);

% applies a moving average filter
%[df,kf] = MA_Filter(d(k,1:3),NFilter,NUnits,dt,'triangular');

% =====================================================
% figure 01: data in time (raw + filtered + rainfall)
figure(1), orient tall, clf

subplot(5,1,3:4), extaxes
plot(t(k),d(k,1),'.','MarkerSize',.1)
ylim = get(gca,'YLim');
hold on
%plot(t(k(kf)),df(kf,1),'k','LineWidth',1.5)
% plots intervention
for i = 1:size(t_pb,1)
	area(t_pb(i,:),repmat(ylim(2),1,2),ylim(1),'EdgeColor',gris,'FaceColor',gris);
end
hold off
datetick('x')
xlim = get(gca,'XLim');
set(gca,'FontSize',8)
ylabel('Relative level (m)')
title(sprintf('Last value = %g m',d(end,1)))

subplot(5,1,1:2), extaxes
plot(t(k),d(k,2:3),'.','MarkerSize',.1)
hold on
%plot(t(k(kf)),df(kf,2:3),'k','LineWidth',2)
hold off
datetick('x')
set(gca,'XLim',xlim,'FontSize',8)
ylabel('Temperatures (C)')
title(sprintf('Last values = %g C, %g C',d(end,2:3)))
legend('CTN 1','CTN 2','filtered',0)

subplot(5,1,5), extaxes
kimp = find(METEO(2).time>=t(k(1)) & METEO(2).time<=t(k(end)));
area(METEO(2).time(kimp),METEO(2).data(kimp,11))
colormap([0,1,1])
set(gca,'XLim',xlim,'FontSize',8)
datetick('x','keeplimits')
ylabel(sprintf('Rainfall (mm/day)'))

xlabel(sprintf('%s - %s',datestr(t(k(1))),datestr(t(end))))

matpad('OVSG-IPGP - [FB+DG]',0,[],f);

f = sprintf('%s/%s_01',pdat,rcode);
print(sprintf('%s.eps',f),'-depsc','-painters')
disp(sprintf('Graph: %s.eps updated.',f))
unix(sprintf('%s -density 300x300 %s.eps %s.png',X.PRGM_CONVERT,f,f));
unix(sprintf('%s -scale 100x105 %s.png %s.jpg',X.PRGM_CONVERT,f,f));
disp(sprintf('Graph: %s.png converted.',f))



