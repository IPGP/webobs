function sgramlily(tlim,cscale)
% MOTIF Project
%
% sgramlily: makes sgram for last day of LILY data
%
% Author: F. Beauducel, IPGP
% Created: 2011-01-20
% Updated: 2012-04-24


X = readconf;

% Stations
ST = struct( ...
	'net',{'PF','PF','PF'}, ...
	'cod',{'PARI','ENCI','BERI'}, ...
	'loc',{'00','00','00'}, ...
	'nam',{'Piton Partage','Enclos','Piton de Bert'}, ...
	'cid',{{'LAE','LAN'},{'LAE','LAN'},{'LAE','LAN'}}, ...
	'cnm',{{'Tilt X','Tilt Y'},{'Tilt X','Tilt Y'},{'Tilt X','Tilt Y'}}, ...
	'caz',{{'?','?'},{'N115','N25'},{'?','?'}} ...
	);

[s,hostname] = unix('hostname');
if ~s && ~isempty(findstr(hostname,'puys-ramond'))
	pdata = X.MOTIF_DATA;
	psgram = X.MOTIF_SGRAM;
else
	pdata = '/Users/beaudu/volcans/Fournaise/MOTIF/data';
	psgram = sprintf('%s/sgram',pdata);
end
mfile = mfilename;
samp = 1/86400; % sampling period (in days)
delay = str2num(X.MOTIF_SGRAM_DELAY_HOURS)/24; % delay for real-time (in days)
check = str2num(X.MOTIF_SGRAM_UPDATE_DAYS); % window for check of images existance (in days)
convert = X.PRGM_CONVERT;

if nargin < 1
	tlim = floor(now - delay);
	tchk = tlim - (0:check);
else
	tchk = tlim;
end

if nargin < 2
	cscale = [0,10];
end

axpos1 = [.06,.05,.3,.9];
axpos2 = [.54,.05,.3,.9];
axsig = .12;
xtick = [.005,.01:.01:.05,.1:.1:.5]';
xticklabel = {'0.005','0.01','','','','0.05','0.1','','','','0.5'};
ytick = (0:23)';
cpr = X.MOTIF_COPYRIGHT;
ptmp = X.MOTIF_TMP_DIR;
ftmp = sprintf('%s/sgramlily.eps',ptmp);


for tt = tchk
	ytd = datevec(tt);
	ytds = sprintf('%d%02d%02d',ytd(1:3));

	for st = 1:length(ST)

		stn = ST(st).cod;
		p = sprintf('%s/%d',psgram,ytd(1));
		fimg = sprintf('%s_%s_sgram',stn,ytds);
		fpng = sprintf('%s/%s.png',p,fimg);
		complete = 0;
		if exist(fpng,'file')
			[s,w] = unix(sprintf('%s -format %%[MOTIF_complete] %s',X.PRGM_IDENTIFY,fpng));
			wn = str2num(w);
			if ~isempty(wn)
				complete = 1 - wn;
			end
		end

		if ~isempty(find(tt==tlim)) | complete > 0.01 | ~exist(fpng,'file')
			
			fdat = sprintf('%s/%s.dat',ptmp,stn);
			unix(sprintf('rm -f %s',fdat));
		
			% imports 1-day of data
			if ~unix(sprintf('cat %s/%d/%s/%s_%s_??.dat > %s',pdata,ytd(1),ytds,stn,ytds,fdat))

				[yy,mm,dd,hh,nn,ss,dx,dy,bs,tl,al,dt] = textread(fdat,'%n-%n-%n%n:%n:%n%n%n%n%n%n%n','commentstyle','shell');
				%[yy,mm,dd,hh,nn,ss,dx,dy] = textread(fdat,'%n-%n-%n%n:%n:%n%n%n%*[^\n]');
				% time vector from GPS timestamp ti
				ti0 = datenum(yy,mm,dd,hh,nn,ss);
				t1 = (ti0(1):samp:ti0(end))';
				dti = [0;diff(ti0)];
				complete = diff(ti0([1,end]));

				% time vector from LILY sample rate
				dt(abs(dt)>86400) = 0;	% forces to 0 if too big
				til = datenum(yy,mm,dd,hh,nn,floor(ss) + dt - dt(1));
				kn = find(diff(til<=0));
				til(kn+1) = til(kn) + samp;	% time vector at +/- 1 s precision
				dtl = diff(til);
				dtl(find(dtl<=2.1*samp)) = samp;
				ti = cumsum([ti0(1);dtl]);	% "clean" time vector !
				k0 = find(diff(ti)>2*samp);
				mmx = minmax(dx);
				mmy = minmax(dy);

				figure(1), clf, orient tall
				axes('Position',axpos1)
				if length(dx) > 256
					[S,F,T] = spectrogram(interp1(ti,dx,t1,'nearest')-median(dx),256,128,256,1);
					%imagesc(F,ti(1)+T/86400,cleangap(T,abs(S)',ti,k0)), axis xy, caxis(cscale)
					pcolor(F,ti(1)+T/86400,cleangap(T,abs(S)',ti,k0)), caxis(cscale), shading interp
					%pcolor(F,ti(1)+T/86400,abs(S)'), caxis(cscale), shading interp
				end
				set(gca,'YLim',tt+[0,1],'YTick',tt+ytick/24,'YTickLabel',num2str(ytick,'%02d:00'), ...
					'XLim',[.005,.5],'XScale','log','XTick',xtick,'XTickLabel',xticklabel,'XGrid','on','GridLineStyle','-', ...
					'Layer','top','FontSize',7,'FontWeight','bold')
				xlabel('Frequency (Hz)')
				title(sprintf('%s:%s:%s:%s / %s (%s)',ST(st).net,ST(st).cod,ST(st).loc,ST(st).cid{1},ST(st).cnm{1},ST(st).caz{1}),'FontSize',9)	
				axes('Position',[axpos1(1)+axpos1(3)+.01,axpos1(2),axsig,axpos1(4)])
				plot(dx,ti0,'k-',mavr(dx,60),ti0,'r-',mmx(1)+diff(mmx)*(dti-min(dti))/diff(minmax(dti)),ti0,'g-')
				set(gca,'XLim',mmx,'YLim',tt+[0,1],'XTick',[],'YTick',[])
				text(mmx(2),tt,sprintf('pp = %1.2f urad\nmean = %+1.2f urad\nstd diff = %1.2f urad',diff(mmx),mean(dx),std(diff(dx))), ...
					'VerticalAlignment','top','HorizontalAlignment','right','Fontsize',6)
				text(mmx(2),tt+1,sprintf('dt = %1.3f to %1.3f s',minmax(dti)*86400),'VerticalAlignment','bottom','HorizontalAlignment','right','Fontsize',6)

				axes('Position',axpos2)
				if length(dy) > 256
					[S,F,T] = spectrogram(interp1(ti,dy,t1,'nearest')-median(dy),256,128,256,1);
					%imagesc(F,ti(1)+T/86400,cleangap(T,abs(S)',ti,k0)), axis xy, caxis(cscale)
					pcolor(F,ti(1)+T/86400,cleangap(T,abs(S)',ti,k0)), caxis(cscale), shading interp
				end
				set(gca,'YLim',tt+[0,1],'YTick',tt+ytick/24,'YTickLabel',num2str(ytick,'%02d:00'), ...
					'XLim',[.005,.5],'XScale','log','XTick',xtick,'XTickLabel',xticklabel,'XGrid','on','GridLineStyle','-', ...
					'Layer','top','FontSize',7,'FontWeight','bold')
				xlabel('Frequency (Hz)')
				title(sprintf('%s:%s:%s:%s / %s (%s)',ST(st).net,ST(st).cod,ST(st).loc,ST(st).cid{2},ST(st).cnm{2},ST(st).caz{2}),'FontSize',9)	
				axes('Position',[axpos2(1)+axpos2(3)+.01,axpos2(2),axsig,axpos2(4)])
				plot(dy,ti0,'k-',mavr(dy,60),ti0,'r-',mmy(1)+diff(mmy)*(dti-min(dti))/diff(minmax(dti)),ti0,'g-')
				set(gca,'XLim',mmy,'YLim',tt+[0,1],'XTick',[],'YTick',[])
				text(mmy(2),tt,sprintf('pp = %1.2f urad\nmean = %+1.2f urad\nstd diff = %1.2f urad',diff(mmy),mean(dy),std(diff(dy))), ...
					'VerticalAlignment','top','HorizontalAlignment','right','Fontsize',6)
				text(mmy(2),tt+1,sprintf('dt = %1.3f to %1.3f s',minmax(dti)*86400),'VerticalAlignment','bottom','HorizontalAlignment','right','Fontsize',6)

				% title and signature
				axes('Position',[0,0,1,1]), axis off
				text(.5,.99,sprintf('%s LILY Tiltmeter @ 1 Hz - %s UTC',ST(st).nam,datestr(ytd)), ...
					'HorizontalAlignment','center','VerticalAlignment','top','Fontsize',12,'FontWeight','bold')
				text(.5,.01,sprintf('%s, %s - %s - %s.m @ %s - %s UTC',cpr,datestr(now,'yyyy'),fimg,mfile,strtrim(hostname),datestr(now)), ...
					'HorizontalAlignment','center','Fontsize',6,'Color',.3*[1,1,1],'Interpreter','none')


				% PNG tag properties
				tag = [ ...
					sprintf('-set MOTIF_complete "%g" ',complete), ...
				];

				%print('-depsc','-painters',ftmp)
				%unix(sprintf('convert -density 100 %s %s.png',ftmp,fimg));
				print('-dpng','-painters','-r130',sprintf('%s/%s.png',ptmp,fimg))
				unix(sprintf('%s -scale 80 %s/%s.png %s/%s.jpg',convert,ptmp,fimg,ptmp,fimg));
				unix(sprintf('%s %s %s/%s.png %s/%s.png',convert,tag,ptmp,fimg,p,fimg));
				unix(sprintf('mkdir -p %s/vign',p));
				unix(sprintf('mv %s/%s.jpg %s/vign/.',ptmp,fimg,p));
				fprintf('Graph: %s/%s.png made.\n',p,fimg)

				% makes link to last image
				unix(sprintf('ln -sf %d/%s.png %s/%s_last.png',ytd(1),fimg,psgram,stn));
				unix(sprintf('ln -sf %d/vign/%s.jpg %s/%s_last.jpg',ytd(1),fimg,psgram,stn));
			end
		end
	end
end

%========================================================
function S = cleangap(T,S,ti,k0)

if ~isempty(k0)
	T = ti(1) + T/86400;
	for i = 1:length(k0)
		S(T>ti(k0(i)) & T<ti(k0(i)+1),:) = NaN;
	end
end

