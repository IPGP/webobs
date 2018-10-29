function DOUT=gamit(proc,tlim,OPT,nograph,dirspec)
%GAMIT	Plots all graphs from continuous GPS network.
%       GAMIT(PROC) loads recent data from disk and updates all graphs on WEBOBS for process PROC.
%
%       GAMIT(PROC,TLIM,OPT,NOGRAPH) makes the following:
%           TLIM = DT or [T1;T2] plots a specific graph (extension '_xxx') for the 
%               last DT days, or on period betweendates T1 and T2, with vectorial format 
%               [YYYY MM DD] or [YYYY MM DD hh mm ss].
%           TLIM = 'all' plots a graphe of all the avalaible data time interval ('_all').
%           OPT.fmt = date format (see DATETICK).
%           OPT.mks = marker size.
%           OPT.cum = time cumulation interval for histograms (in days).
%           OPT.dec = decimation of data (in samples).
%           NOGRAPH = 1 (optionnal) do not plots any graphs.
%
%       DOUT = GAMIT(...) returns a structure DOUT containing all the data from 
%       stations :
%           DOUT(i).code = station code (for station i)
%           DOUT(i).time = time vector (for station i)
%           DOUT(i).data = matrix of processed data (NaN = invalid data)
%
%
%   Authors: F. Beauducel + A. Peltier / IPGP
%   Created: 2010-06-12
%   Updated: 2013-04-15

if nargin < 1
	error('WEBOBS{%s}: must define conf file.',mfilename);
end

X = readconf;

if nargin < 2, tlim = []; end
if nargin < 3, OPT = 0; end
if nargin < 4, nograph = 0; end
if nargin < 5, dirspec = X.MKSPEC_PATH_WEB; end
%if nargout > 0, nograph = 1; end

rcode = proc;
timelog(rcode,1);

% Initializing variables
G = readgr(rcode);
tnow = datevec(G.now);

G.dsp = dirspec;
ST = readst(G.cod,G.obs);
ist = [find(~strcmp(ST.ali,'-') & ~strcmp(ST.dat,'-') & ~strcmp(ST.dat,''))];
aliases = [];
s = split(G.ftp,'/');
chantier = s{end};
fevents = sprintf('events_%s.conf',upper(chantier));

tlast = nan(length(ist),1);
tfirstall = NaN;

samp = 1;	% sampling rate (in days)
pftp = sprintf('%s/%s',X.RACINE_FTP,G.ftp);
ptmp = sprintf('/tmp/.webobs');
system(sprintf('mkdir -p %s',ptmp));
% get GLOBK reference
%datatype = sprintf('ITRF %s',X.ITRF_YEAR);
datatype = '';
f = sprintf('%s/gsoln.templates/globk_comb.cmd',pftp);
[s,w] = system(sprintf('grep apr_file %s | sed "s/.*tables\\///" | sed "s/\\.apr//"',f));
if exist(f,'file') & s == 0
	datatype = sprintf(' - %s',upper(strtrim(w)));
end

for n = 1:length(ist)

	st = ist(n);
	scode = ST.cod{st};
	alias = ST.ali{st};
	datid = split(ST.dat{st},',');
	sname = ST.nom{st};
	stitre = sprintf('%s: %s %s',alias,sname,datatype);
	stype = 'T';

	t = [];
	d = [];

	% loop on potential list of dataIDs
	for nn = datid
		sdata = strtrim(nn{:});

		% Extracts components from VAL file
		for c = {'E','N','U'}
			system(sprintf('sed -n "/%s_GPS to %s/,/Wmean/p" %s/VAL.%s | tail -n +3 | head -n -2 > %s/%s_%s.dat',sdata,c{:},pftp,chantier,ptmp,sdata,c{:}));
		end

		% Concatenates to a single file
		f = sprintf('%s/%s.dat',ptmp,sdata);
		system(sprintf('paste %s/%s_?.dat > %s',ptmp,sdata,f));

		% Load the file
		if exist(f,'file')
			dd = load(f);
			disp(sprintf('File: %s imported (%d data).',f,size(dd,1)));
			if ~isempty(dd)
				t = cat(1,t,datenum([dd(:,1:5),zeros(size(dd,1),1)]));
				d = cat(1,d,dd(:,[6,15,24,7,16,25]));
			end
		end

		% Cleaning
		delete(sprintf('%s/%s*.dat',ptmp,sdata))
	end

	% Calibrates the data
	if ST.clb(st).nx > 0
		[d,C] = calib(t,d,ST.clb(st));
	else
		C.nm = {'Eastern','Northern','Vertical'};
		C.un = {'m','m','m'};
	end
	nx = length(C.nm);
	so = 1:nx;


	% Stores in other variables to prepare the synthesis graph
	eval(sprintf('d_%d=d;t_%d=t;',n,n));
	
	if ~isempty(t)
		tlast(n) = rmax(t);
		tfirst = rmin(t);
		tfirstall = min(tfirstall,tfirst);
	else
		tlast(n) = now;
		tfirst = now-1;
	end
	kall = find(strcmp(G.ext,'all'));
	if ~isempty(kall)
		G.lim{kall}(1) = tfirst;
	end

	% Interprétation des arguments d'entrée de la fonction
	%	- t1 = temps min
	%	- t2 = temps max
	%	- structure G = paramètres de chaque graphe
	%		.ext = type de graphe (durée) "station_EXT.png"
	%		.lim = vecteur [tmin tmax]
	%		.fmt = numéro format de date (fonction DATESTR) pour les XTick
	%		.cum = durée cumulée pour les histogrammes (en jour)
	%		.mks = taille des points de données (fonction PLOT)

	% Decoding argument TLIM
	if isempty(tlim)
		ivg = find(~strcmp(G.ext,'xxx'));
	end
	if strcmp(tlim,'all') & ~isempty(kall)
		ivg = kall;
	end
	if ~isempty(tlim) & ~ischar(tlim)
		if size(tlim,1) == 2
			t1 = datenum(tlim(1,:));
			t2 = datenum(tlim(2,:));
		else
			t2 = datenum(tnow);
			t1 = t2 - tlim;
		end
		ivg = length(G.ext);
		G.lim{ivg} = minmax([t1 t2]);
		if nargin > 2
			G.fmt{ivg} = OPT.fmt;
			G.mks{ivg} = OPT.mks;
			G.cum{ivg} = OPT.cum;
		end
	end

	% Renvoi des données dans DOUT, sur la période de temps G.lim(end)
	if nargout > 0
		k = find(t>=G.lim{ivg(1)}(1) & t<=G.lim{ivg(1)}(2));
		DOUT(1).code = scode;
		DOUT(1).time = t(k);
		DOUT(1).data = d(k,:);
		DOUT(1).chan = C.nm;
		DOUT(1).unit = C.un;
	end

	% Si nograph==1, quitte la routine sans production de graphes
	if nograph == 1
		ivg = []; 
		disp('Option NOGRAPH set: no graph produced.');
	end


	% ===================== Tracé des graphes

	for ig = ivg

		figure, clf, orient tall
		k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
		if isempty(k)
			k1 = [];
			ke = [];
		else
			k1 = k(1);
			ke = k(end);
		end

		% Etat de la station
                kacq = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
                if isempty(kacq)
			acqui = 0;
		else
			acqui = round(100*length(kacq)*samp/abs(t(kacq(end)) - G.lst - G.lim{ig}(1)));
		end
		if t(ke) >= G.lim{ig}(2)-G.lst
			etat = 0;
			for i = 1:nx
				if ~isnan(d(ke,i))
					etat = etat+1;
				end
			end
			etat = 100*etat/nx;
		else
			etat = 0;
		end
    

		% Titre et informations
		G.tit = gtitle(stitre,G.ext{ig});
		G.eta = [G.lim{ig}(2),etat,acqui];
		etats(st) = etat;
		acquis(st) = acqui;
		G.inf = {''};
		if ig == 1
			if ig == 1
				sd = '';
				for i = 1:nx
					if ~isempty(d)
						sd = [sd sprintf(', %1.1f %s', d(end,i),C.un{i})];
					else
						sd = [sd ', no data'];
					end
				end
				mketat(etat,tlast(n),sd(3:end),lower(scode),G.utc,acqui)
			end
		end

		% loop for Relative Eastern, Northern, and Up components with error bars (in m)
		xlim = [G.lim{ig}(1) G.lim{ig}(2)];
		lre = nan(3,2);
		for i = 1:3
			subplot(6,1,(i-1)*2+(1:2)), extaxes
			if ~isempty(k)
				dd = cleanpicks(d(k,i)-d(k1,i));
				plot(t(k),dd,'.','MarkerSize',G.mks{ig})
				set(gca,'Ylim',get(gca,'YLim'))	% freezes Y axis: adjusted on data (not on error bars)
				hold on
				plot(repmat(t(k),[1,2])',(repmat(dd,[1,2])+d(k,i+3)*[-1,1])','-','LineWidth',.1,'Color',.6*[1,1,1])
				set(gca,'Children',flipud(get(gca,'Children'))); % reverses objects order (data on the top)
				kk = find(~isnan(dd));
				if length(kk) > 2
					[lr,stdx] = wls(t(k(kk))-t(k1),dd(kk),1./d(k(kk),i+3).^2);
					lre(i,:) = [lr(1),stdx(1)]*365.25*1e3;
					plot(xlim,polyval(lr,xlim - t(k1)),'--k','LineWidth',.2)
				end
				hold off
			end
			set(gca,'XLim',xlim,'FontSize',8)
			datetick2('x',G.fmt{ig},'keeplimits')
			ylabel(sprintf('Relative %s (%s)',C.nm{i},C.un{i}))
			if isempty(d) | length(find(~isnan(d(k,i))))==0
				nodata(G.lim{ig})
			end
		end

		tlabel(G.lim{ig},G.utc)
		plotevent(fevents)

		if ~isempty(k)
			G.inf = {sprintf('Last measurement: {\\bf%s} {\\it%+d}',datestr(t(ke)),G.utc),' (min|moy|max)',' ',' '};
			for i = 1:3
				G.inf = [G.inf{:},{sprintf('%d. %s = {\\bf%+1.3f %s} (%+1.3f | %+1.3f | %+1.3f) - Trend = {\\bf%+1.3f \\pm %1.3f mm/yr}', ...
					i, C.nm{i},d(ke,i)-d(k1,i),C.un{i},rmin(d(k,i)-d(k1,i)),rmean(d(k,i)-d(k1,i)),rmax(d(k,i)-d(k1,i)),lre(i,:))}];
			end
		end
		
		% makes graph
		mkgraph(sprintf('%s_%s',lower(scode),G.ext{ig}),G,OPT)
		close

		% exports data
		if ~isempty(k)
			E.t = t(k);
			E.d = d(k,:);
			E.header = {'Eastern(m)','Northern(m)','Up(m)','dE','dN','dU'};
			E.title = sprintf('%s {%s}',stitre,upper(scode));
			mkexport(sprintf('%s_%s',scode,G.ext{ig}),E,G);
		end
	end
end


% ====================================================================================================
% Graphs for all the network

stitre = sprintf('%s %s',G.nom,datatype);
etat = mean(etats);
acqui = mean(acquis);

for ig = ivg

	G.tit = gtitle(stitre,G.ext{ig});
	G.eta = [G.lim{ig}(2),etat,acqui];
	G.inf = {''};
	if strcmp(G.ext{ig},'all')
		G.lim{ig}(1) = tfirstall;
	end
	xlim = [G.lim{ig}(1) G.lim{ig}(2)];
	tr = nan(length(ist),3); % trends per station per component (mm/yr)
	tre = nan(length(ist),3); % trends error (mm/yr)


	% --- Time series graph
	figure, clf, orient tall

	for i = 1:3
		subplot(6,1,(i-1)*2+(1:2)), extaxes
		hold on
		aliases = [];
		ncolors = [];
		for n = 1:length(ist)
			
			eval(sprintf('d=d_%d;t=t_%d;',n,n));
			k = find(t>=G.lim{ig}(1) & t<=G.lim{ig}(2));
			if ~isempty(k)
				dd = cleanpicks(d(k,i)-d(k(1),i));
				kk = find(~isnan(dd));
				if length(kk) > 2
					[b,stdx] = wls(t(k(kk))-t(k(1)),dd(kk),1./d(k(kk),i+3).^2);
					tr(n,i) = b(1)*365.25*1e3;
					tre(n,i) = stdx(1)*365.25*1e3;
				end
				plot(t(k),cleanpicks(d(k,i) - d(k(1),i)),'.','Color',scolor(n),'MarkerSize',G.mks{ig})
				aliases = [aliases,ST.ali(ist(n))];
				ncolors = [ncolors,n];
			end
		end
		hold off
		set(gca,'XLim',xlim,'FontSize',8)
		box on
		datetick2('x',G.fmt{ig},'keeplimits')
		ylabel(sprintf('Relative %s (%s)',C.nm{i},C.un{i}))
		
		% legend: station aliases
		xlim = get(gca,'XLim');
		ylim = get(gca,'YLim');
		nn = length(aliases);
		fs = 6;
		if nn > 25
			fs = 100/nn + 2;
		end
		for n = 1:nn
			text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),aliases(n),'Color',scolor(ncolors(n)), ...
				'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',fs,'FontWeight','bold')
		end
		set(gca,'YLim',ylim);
	end

	tlabel(G.lim{ig},G.utc)
	plotevent(fevents)
    
	mkgraph(sprintf('%s_%s',rcode,G.ext{ig}),G,OPT)
	close

	% latitude extent of network
	ylim = minmax(ST.geo(ist,1));

	% xy ratio
	xyr = cosd(mean(ylim));

	% scale is adjusted to maximum horizontal vector or error amplitude (in mm/yr)
	vmax = rmax([abs(complex(tr(:,1),tr(:,2)));abs(complex(tre(:,1),tre(:,2)))/2]);
	vsc = .25*diff(ylim)/vmax;

	% --- Vectors map
	arrowshape = [.1,.1,.08,.02];
	figure, clf, orient tall

	ha = plot(ST.geo(ist,2),ST.geo(ist,1),'k.');
	hold on
	% plots velocity vectors first
	for n = 1:length(ist)
		st = ist(n);
		if ~any(isnan([vsc,vmax])) & ~any(isnan(tr(n,:)))
			h = arrows(ST.geo(st,2),ST.geo(st,1),vsc*tr(n,1)/xyr,vsc*tr(n,2),arrowshape,'Cartesian','Ref',vsc*vmax,'FaceColor',scolor(n),'LineWidth',1);
			ha = [ha;h];
		end
	end
	% fixes the axis
	axis tight
	axl = axis;
	dx = .05;	% extends axis limits
	xlim = [axl(1) - dx*diff(axl(1:2)),axl(2) + dx*diff(axl(1:2))];
	ylim = [axl(3) - dx*diff(axl(3:4)),axl(4) + dx*diff(axl(3:4))];
	set(gca,'XLim',xlim,'YLim',ylim);

	% gets local DEM or SRTM data and plots a basemap
	if isfield(G,'dem') & exist(sprintf('%s/%s',X.DATA_DEM,G.dem))
		% ATTENTION: user defined DEM must be in Lat/Lon WGS84 and Arcinfo ASCII format !
		[x,y,z] = igrd(sprintf('%s/%s',X.DATA_DEM,G.dem));
		kx = find(x>= xlim(1) & x <= xlim(2));
		ky = find(y>= ylim(1) & y <= ylim(2));
		D.lon = x(kx);
		D.lat = y(ky);
		D.z = z(ky,kx);
		D.cpr = sprintf('DEM from %s',G.dem);
	else
		D = readhgt(floor(ylim(1)):floor(ylim(2)),floor(xlim(1)):floor(xlim(2)),X.DATA_DEM_SRTM,'merge','crop',[ylim,xlim]);
		D.cpr = 'DEM from NASA/SRTM';
	end
	dem(D.lon,D.lat,D.z,'latlon','watermark',2,'interp','legend')
	text(xlim(2),ylim(2)+.01*diff(ylim),D.cpr,'HorizontalAlignment','right','VerticalAlignment','bottom','Interpreter','none','FontSize',6)

	% plots stations
	target(ST.geo(ist,2),ST.geo(ist,1),7);

	% puts arrows on top
	h = get(gca,'Children');
	ko = find(h == ha(1));
	set(gca,'Children',[ha;h(1:ko)])
	
	% plots error ellipse and station name
	for n = 1:length(ist)
		st = ist(n);
		if ~isnan(any(tr(n,:)))
			h = ellipse(ST.geo(st,2) + vsc*tr(n,1)/xyr,ST.geo(st,1) + vsc*tr(n,2),vsc*tre(n,1)/xyr,vsc*tre(n,2), ...
				'EdgeColor',scolor(n),'LineWidth',.2,'Clipping','on');
			ha = [ha;h];
		end
		% text position depends on vector direction
		if tr(n,2) > 0
			stn = {'','',ST.ali{st}};
		else
			stn = {ST.ali{st},'',''};
		end
		text(ST.geo(st,2),ST.geo(st,1),stn,'FontSize',7,'FontWeight','bold', ...
			'VerticalAlignment','Middle','HorizontalAlignment','Center')
	end

	% plots legend scale
	vscale = roundsd(vmax,1);
	xsc = xlim(1);
	ysc = ylim(2) + .03*diff(ylim);
	lsc = vscale*vsc;
	arrows(xsc,ysc,lsc,90,arrowshape*vmax/vscale,'FaceColor','none','LineWidth',1,'Clipping','off');
	text(xsc+1.1*lsc,ysc,sprintf('%g mm/yr',vscale),'FontWeight','bold')


	hold off

	rcode2 = sprintf('%s_VECTORS',rcode);
	mkgraph(sprintf('%s_%s',rcode2,G.ext{ig}),G,OPT)
	close

	% exports data
	E.t = tlast;
	E.d = [ST.geo(ist,:),tr,tre];
	E.header = {'Latitude','Longitude','Altitude','E_velocity(mm/yr)','N_Velocity(mm/yr)','Up_Velocity(mm/yr)','dEv(mm/yr)','dNv(mm/yr)','dUv(mm/yr)'};
	E.title = sprintf('%s {%s}',stitre,upper(rcode2));
	mkexport(sprintf('%s_%s',rcode2,G.ext{ig}),E,G);

end

if isempty(tlim)
	mketat(etat,rmax(tlast),sprintf('%s %d stations',stype,length(etats)),rcode,G.utc,acqui)
	G.sta = [{rcode};{rcode2};lower(ST.cod(ist))];
	G.ali = [{rcode};{'VECTORS'};ST.ali(ist)];
	G.ext = G.ext(ivg);
	htmgraph(G);
end


timelog(rcode,2)


