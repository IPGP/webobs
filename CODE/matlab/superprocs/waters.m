function DOUT = waters(varargin)
%WATERS  WebObs SuperPROC: Updates graphs/exports of 'EAUX' FORM database.
%
%       WATERS(PROC) makes default outputs of PROC.
%
%       WATERS(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%           TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%           (keywords must be in TIMESCALELIST of PROC.conf)
%
%       WATERS(PROC,[],REQ) makes graphs/exports for specific request directory REQ.
%       REQ must contain REQUEST.rc file with dedicated parameters.
%
%       D = WATERS(PROC,...) returns a structure Dcontaining all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%	WATERS ignores any calibration file of associated NODEs. Channels are defined
%	by the FORM "EAUX" and associated configuration files. See readfmtdata_wodbform.m for
%	further information.
%
%	**WARNING** this file must be iso-8859 (unicode) encoded and NOT utf-8
%
%	Authors: F. Beauducel + G. Hammouya + J.C. Komorowski + C. Dessert + O. Crispi, OVSG-IPGP
%	Created: 2001-12-21, in Guadeloupe (French West Indies)
%	Updated: 2024-01-04

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

proc = varargin{1};
procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);

% gets PROC's configuration and associated nodes
[P,N,D] = readproc(WO,varargin{:});
G = cat(1,D.G);

% types of sampling and associated markers (see PLOTMARK function)
FT = readcfg(WO,sprintf('%s/%s',P.FORM.ROOT,P.FORM.FILE_TYPE));
tcod = fieldnames(FT);
tmkt = cell(size(tcod));
tmks = ones(size(tcod));
for i = 1:length(tcod)
	tmkt{i} = FT.(tcod{i}).marker;
	tmks(i) = str2double(FT.(tcod{i}).relsize);
end

% --- index of columns in matrix d
%   1 = type of site
i_ty = 1;
%   2 = temperature of air (°C)
i_ta = 2;
%   3 = temperature of water (°C)
i_ts = 3;
%   4 = pH
i_ph = 4;
%   5 = flux (l/mn)
i_db = 5;
%   6 = conductivity (µS)
i_cd = 6;
%   7 = level (m)
i_nv = 7;
%   8-18 = concentrations in ppm = mg/l, to be converted in mmol/l
%   8-12 = anions Li+, Na+, K+, Mg++, Ca++ (mmol/l)
i_li = 8;
i_na = 9;
i_ki = 10;
i_mg = 11;
i_ca = 12;
%   13-18 = cations F-,Cl-,Br-,NO3-,SO4--,HCO3-,I- (mmol/l)
i_fi = 13;
i_cl = 14;
i_br = 15;
i_no3 = 16;
i_so4 = 17;
i_hco3 = 18;
i_i = 19;
%   20-22 = isotopes d13C, d18O,dD
%   23 = ratio Cl-/SO4-- (computed)
%   24 = ratio HCO3-/SO4-- (computed)
%   25 = ratio Mg++/Cl- (computed)
%   26 = conductivity at 25°C
%   27 = ion budget (NICB)
i_bi = 27;


% ==== graphs per site
for n = 1:length(N)
	stitre = sprintf('%s: %s',N(n).ALIAS,N(n).NAME);

	t = D(n).t;
	d = D(n).d;

	for r = 1:length(P.GTABLE)

		% renames main variables for better lisibility...
		k = D(n).G(r).k;
		ke = D(n).G(r).ke;
		tlim = D(n).G(r).tlim;

		% title and status
		P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
		P.GTABLE(r).GSTATUS = [tlim(2),D(n).G(r).last,D(n).G(r).samp];

		figure(1), clf, orient tall

		if d(ke,i_db) == 0, sdb = 'TARIE'; else sdb = sprintf('%1.1f l/mn',d(ke,i_db)); end
		P.GTABLE(r).INFOS = {sprintf('Last meas.: {\\bf%s} {\\it%+d}',datestr(t(ke)),P.TZ), ...
			sprintf('Twater = {\\bf%1.1f °C}',d(ke,i_ts)), ...
			sprintf('Tair = {\\bf%1.1f °C}',d(ke,i_ta)), ...
			sprintf('pH = {\\bf%1.2f}',d(ke,i_ph)), ...
			sprintf('Cond. = {\\bf%1.1f µS}',d(ke,i_cd)), ...
			sprintf('Cond_{25} = {\\bf%1.1f µS}',d(ke,25)), ...
			sprintf('Flux = {\\bf%s}',sdb), ...
			sprintf('Ion analysis ({\\bfmmol/l}) :'), ...
			sprintf('Na^+ = {\\bf%1.1f}',d(ke,i_na)), ...
			sprintf('K^+ = {\\bf%1.1f}',d(ke,i_ki)), ...
			sprintf('Mg^{++} = {\\bf%1.1f}',d(ke,i_mg)), ...
			sprintf('Ca^{++} = {\\bf%1.1f}',d(ke,i_ca)), ...
			sprintf('F^- = {\\bf%1.1f}',d(ke,i_fi)), ...
			sprintf('Cl^- = {\\bf%1.1f}',d(ke,i_cl)), ...
			sprintf('HCO_3^- = {\\bf%1.1f}',d(ke,i_hco3)), ...
			sprintf('SO_4^{--} = {\\bf%1.1f}',d(ke,i_so4)), ...
			sprintf('Cl^- / SO_4^{--} = {\\bf%1.2f}',d(ke,i_cl)), ...
			sprintf('HCO_3^- / SO_4^{--} = {\\bf%1.2f}',d(ke,i_hco3)), ...
			sprintf('NICB = {\\bf%+1.2f %%}',d(ke,i_bi)), ...
		};

		% Temperatures (water + air)
		subplot(12,1,1:2), extaxes
		% --- air
		plot(t(k),d(k,i_ta),'.-','LineWidth',.1,'Color',.6*[1 1 1]), hold on
		% --- water marker following site type
		plotmark(d(k,i_ty),t(k),d(k,i_ts),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(1))
		hold off
		set(gca,'XLim',tlim,'FontSize',8)
		legend('Air','Location','SouthWest')
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Temperatures (°C)')

		% Legend for site types
		pos = get(gca,'position');
		axes('position',[pos(1),pos(2)+pos(4),pos(3),pos(4)/5])
		axis([0 1 0 1]), hold on
		for i = 1:length(tcod)
			plot((i-1)/length(tcod) + .05,.5,FT.(tcod{i}).marker,'Markersize',P.GTABLE(r).MARKERSIZE*str2double(FT.(tcod{i}).relsize),'MarkerFaceColor','k')
			text((i-1)/length(tcod) + .05,.5,['   ',FT.(tcod{i}).name],'FontSize',8)
		end
		axis off, hold off

		% pH
		subplot(12,1,3:4), extaxes
		dd = d(k,i_ph);
		plotmark(d(k,i_ty),t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(1))
		set(gca,'XLim',tlim,'FontSize',8)
		extylim(dd);
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('pH')

		% Cl- & HCO3-
		subplot(12,1,5:6), extaxes
		dd = d(k,[i_cl,i_hco3]);
		h1 = plotmark(d(k,i_ty),t(k),dd(:,1),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(2));
		hold on
		h2 = plotmark(d(k,i_ty),t(k),dd(:,2),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(3));
		hold off
		set(gca,'XLim',tlim,'FontSize',8)
		extylim(dd);
		if ~isempty(h1) && ~isempty(h2)
			legend([h1(1),h2(1)],'Cl^-','HCO_3^-','Location','SouthWest')
		end
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Cl^- & HCO_3^- (mmol/l)')

		% Cl-/SO4-- & HCO3-/SO4--
		subplot(12,1,7:8), extaxes
		dd =  d(k,23:24);
		h1 = plotmark(d(k,i_ty),t(k),dd(:,1),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(4));
		hold on
		h2 = plotmark(d(k,i_ty),t(k),dd(:,2),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(5));
		hold off
		set(gca,'XLim',tlim,'FontSize',8)
		extylim(dd);
		if ~isempty(h1) && ~isempty(h2)
			legend([h1(1),h2(1)],'Cl^-/SO_4^{--}','HCO_3^-/SO_4^{--}','Location','SouthWest')
		end
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Cl^-/SO_4^{--} & HCO_3^-/SO_4^{--}')

		% Mg++/Cl-
		subplot(12,1,9), extaxes
		dd = d(k,25);
		plotmark(d(k,i_ty),t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(1))
		set(gca,'XLim',tlim,'FontSize',8)
		extylim(dd);
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Mg^{++}/Cl^-')

		% Flux
		subplot(12,1,10), extaxes
		dd = d(k,i_db);
		plotmark(d(k,i_ty),t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(1))
		set(gca,'XLim',tlim,'FontSize',8)
		extylim(dd);
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Flux (l/mn)')

		% Conductivity
		subplot(12,1,11:12), extaxes
		dd = d(k,[i_cd,26]);
		h1 = plotmark(d(k,i_ty),t(k),dd(:,1),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(6));
		hold on
		h2 = plotmark(d(k,i_ty),t(k),dd(:,2),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(7));
		hold off
		set(gca,'XLim',tlim,'FontSize',8)
		extylim(dd);
		if ~isempty(h1) && ~isempty(h2)
			legend([h1(1),h2(1)],'Cond.','Cond_{25}','Location','SouthWest')
		end
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Cond. & Cond_{25} (µS)')

		tlabel(tlim,P.TZ)

		OPT.EVENTS = N(n).EVENTS;
		mkgraph(WO,sprintf('%s_%s',lower(N(n).ID),P.GTABLE(r).TIMESCALE),P.GTABLE(r),OPT)
	end

end

% ==== Main summary graph
if isfield(P,'SUMMARYLIST')
	for r = 1:length(P.GTABLE)

		stitre = P.NAME;
		tlim = [P.GTABLE(r).DATE1,P.GTABLE(r).DATE2];
		if any(isnan(tlim))
			tlim = minmax(cat(1,D.tfirstlast));
		end
		P.GTABLE(r).GTITLE = gtitle(stitre,P.GTABLE(r).TIMESCALE);
		if P.GTABLE(r).STATUS
			P.GTABLE(r).GSTATUS = [tlim(2),rmean(cat(1,G.last)),rmean(cat(1,G.samp))];
		end
		P.GTABLE(r).INFOS = {sprintf('Last meas.: {\\bf%s} {\\it%+d}',datestr(max(cat(1,D.t))),P.TZ),'',''};


		figure(1), clf, orient tall

		% Ternary diagram Ca/Na/Mg
		subplot(9,2,[1 3])
		for n = 1:length(N)
			k = D(n).G(r).k;
			h = ternplot(D(n).d(k,i_ca),D(n).d(k,i_na),D(n).d(k,i_mg),'.',0);
			set(h,'Color',scolor(n));
			set(gca,'FontSize',8)
			hold on
		end
		hold off
		ternlabel('Ca','Na','Mg',0);
		pos = get(gca,'pos');  set(gca,'pos',[pos(1),pos(2)+.02,pos(3),pos(4)])

		% Ternary diagram SO4/HCO3/Cl
		subplot(9,2,[2 4])
		for n = 1:length(N)
			k = D(n).G(r).k;
			h = ternplot(D(n).d(k,i_so4),D(n).d(k,i_hco3),D(n).d(k,i_cl),'.',0);
			set(h,'Color',scolor(n));
			set(gca,'FontSize',8)
			hold on
		end
		hold off
		ternlabel('SO_4','HCO_3','Cl',0);
		pos = get(gca,'pos');  set(gca,'pos',[pos(1),pos(2)+.02,pos(3),pos(4)])

		% Legend
		axes('position',[0,pos(2),1,pos(4)]);
		axis([0,1,0,1]);
		hold on
		for n = 1:length(N)
			xl = .5;
			yl = 1 - n/(length(N)+3);
			plot([xl xl]',yl+[.02 -.02]','-','Color',scolor(n))
			plot(xl+[.02 -.02],[yl yl],'-',xl,yl,'.','LineWidth',.1,'Color',scolor(n))
			text(xl+.03,yl,N(n).ALIAS,'Fontsize',8,'FontWeight','bold')
		end
		hold off
		axis off

		% Temperatures
		subplot(13,1,4:5), extaxes
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
				plotmark(D(n).d(k,i_ty),D(n).t(k),D(n).d(k,i_ts),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on
		set(gca,'XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('Temperatures (°C)'))

		% Legend for site types
		pos = get(gca,'position');
		axes('position',[pos(1),pos(2)+pos(4),pos(3),pos(4)/7])
		axis([0 1 0 1]), hold on
		for i = 1:length(tcod)
		    plot((i-1)/length(tcod) + .05,.5,FT.(tcod{i}).marker,'Markersize',P.GTABLE(r).MARKERSIZE*str2double(FT.(tcod{i}).relsize),'MarkerFaceColor','k')
		    text((i-1)/length(tcod) + .05,.5,['   ',FT.(tcod{i}).name],'FontSize',8)
		end
		axis off, hold off

		% pH
		subplot(13,1,6:7), extaxes
		ddmm = nan(2,1);
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
				dd = D(n).d(k,i_ph);
				ddmm = minmax([ddmm;dd])';
				plotmark(D(n).d(k,i_ty),D(n).t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on, extylim(ddmm)
		set(gca,'XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel(sprintf('pH'))

		% Conductivity at 25C
		subplot(13,1,8:9), extaxes
		ddmm = nan(2,1);
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
				dd = D(n).d(k,26);
				ddmm = minmax([ddmm;dd])';
				plotmark(D(n).d(k,i_ty),D(n).t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on, extylim(ddmm)
		set(gca,'YScale','linear','XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Cond. 25°C (µS)')

		% Ratio Cl-/SO4-
		subplot(13,1,10:11), extaxes
		ddmm = nan(2,1);
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
			    dd = D(n).d(k,23);
			    ddmm = minmax([ddmm;dd])';
			    plotmark(D(n).d(k,i_ty),D(n).t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on, extylim(ddmm)
		set(gca,'YScale','linear','XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('Cl^- / SO_4^{--}')

		% Ratio HCO3-/SO4-
		subplot(13,1,12:13), extaxes
		ddmm = nan(2,1);
		hold on
		for n = 1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
			    dd = D(n).d(k,24);
			    ddmm = minmax([ddmm;dd])';
			    plotmark(D(n).d(k,i_ty),D(n).t(k),dd,tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(n))
			end
		end
		hold off, box on, extylim(ddmm)
		set(gca,'YScale','linear','XLim',tlim,'FontSize',8)
		datetick2('x',P.GTABLE(r).DATESTR)
		ylabel('HCO_3^- / SO_4^{--}')

		tlabel(tlim,P.TZ)

		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r))
	end
end
close

if P.REQUEST
	mkendreq(WO,P);
end

timelog(procmsg,2)


if nargout > 0
	DOUT = D;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function extylim(d)
%EXTYLIM Extends YLim

mm = minmax(d);
if diff(mm) > 0 && ~any(isnan(mm))
	set(gca,'YLim',mm)
end
