function DOUT = volcgas(varargin)
%VOLCGAS  WebObs SuperPROC: Updates graphs/exports of 'GAZ' FORM database.
%
%       VOLCGAS(PROC) makes default outputs of PROC.
%
%       VOLCGAS(PROC,TSCALE) updates all or a selection of TIMESCALES graphs:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%           TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%           (keywords must be in TIMESCALELIST of PROC.conf)
%
%       VOLCGAS(PROC,[],REQ) makes graphs/exports for specific request directory REQ.
%       REQ must contain REQUEST.rc file with dedicated parameters.
%
%       D = VOLCGAS(PROC,...) returns a structure Dcontaining all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%	VOLCGAS ignores any calibration file of associated NODEs. Channels are defined
%	by the FORM "GAZ" and associated configuration files. See readfmtdata_wodbform.m for
%	further information.
%
%
%	Authors: F. Beauducel + G. Hammouya + C. Dessert + A. Bosson, OVSG-IPGP
%	Created: 2003-04-14, in Guadeloupe (French West Indies)
%	Updated: 2023-12-13

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

majorslist = field2num(P,'MAJORS_LIST',[6:15,18]);
majorstypelist = split(field2str(P,'MAJORS_TYPE','P2O5'),',');
majorsmaxn2 = field2num(P,'MAJORS_MAX_N2',10);
GN = graphstr(field2str(P,'NODE_CHANNELS','1,,2,,3,11,,13,,18,,16,,'));
GS = graphstr(field2str(P,'SUMMARY_CHANNELS','1,,2,18,16'));

% types of sampling and associated markers (see PLOTMARK function)
T = readcfg(WO,sprintf('%s/%s',P.FORM.ROOT,P.FORM.FILE_TYPE));
tcod = fieldnames(T);
tmkt = cell(size(tcod));
tmks = ones(size(tcod));
majorstype = [];
for i = 1:length(tcod)
	tmkt{i} = T.(tcod{i}).marker;
	tmks(i) = str2double(T.(tcod{i}).relsize);
	if ismember(tcod{i},majorstypelist)
		majorstype = cat(1,majorstype,i);
	end
end

% flux levels
FF = readcfg(WO,sprintf('%s/%s',P.FORM.ROOT,P.FORM.FILE_DEBITS));



% --- index of columns in matrix d
i_tf = 1;	% fumarole temperature (°C)
i_ph = 2;	% pH
i_fx = 3;	% flux (0 = none to 4 = very high)
i_rn = 4;	% Rn (count/min)
i_ty = 5;	% type of sampling (1 = P2O5, 2 = NaOH, 3 = void)
%   6 to 15 = concentrations H2,He,CO,CH4,N2,H2S,Ar,CO2,SO2,O2 (%)
i_h2   = 6;
i_he   = 7;
i_co   = 8;
i_ch4  = 9;
i_n2  = 10;
i_h2s = 11;
i_ar  = 12;
i_co2 = 13;
i_so2 = 14;
i_o2  = 15;
i_13c = 16;	% isotope d13C
i_18o = 17;	% isotope d18O
i_rsc = 18;	% rapport S/C: (H2S+SO2)/CO2


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

		if ~isempty(ke) && ~isnan(d(ke,i_fx))
			s_flux = htm2tex(FF.(sprintf('KEY%d',d(ke,i_fx))));
		else
			s_flux = '';
		end

		P.GTABLE(r).INFOS = {sprintf('Last meas.: {\\bf%s} {\\it%+d}',datestr(t(ke)),P.TZ),'','','', ...
			sprintf('Tfum = {\\bf%1.1f °C}',d(ke,i_tf)), ...
			sprintf('pH = {\\bf%1.2f}',d(ke,i_ph)), ...
			sprintf('Flux = {\\bf%d} (%s)',d(ke,i_fx),s_flux), ...
			sprintf('S/C = {\\bf%+1.2f %%}',d(ke,i_rsc)), ...
		};

		% loop on selected subplots
		for c = 1:length(GN)

			subplot(GN(c).subplot{:}), extaxes(gca,[.07,.01])
			cn = GN(c).chan;
			if any(ismember(majorslist,cn))
				k = k(ismember(d(k,i_ty),majorstype) & d(k,i_n2) <= majorsmaxn2); % selects valid data for majors
			end
			plotmark(d(k,i_ty),t(k),d(k,cn),tmkt,P.GTABLE(r).MARKERSIZE*tmks,scolor(c))
			set(gca,'XLim',tlim,'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('%s %s',D(n).CLB.nm{cn},regexprep(D(n).CLB.un{cn},'(.+)','($1)')))

			if c == 1
				% Legend for site types
				pos = get(gca,'position');
				axes('position',[pos(1),pos(2)+pos(4),pos(3),pos(4)/10])
				axis([0 1 0 1]), hold on
				for i = 1:length(tcod)
					plot((i-1)/length(tcod) + .05,.5,T.(tcod{i}).marker,'Markersize',P.GTABLE(r).MARKERSIZE*str2double(T.(tcod{i}).relsize),'Color','k','MarkerFaceColor','k')
					text((i-1)/length(tcod) + .05,.5,['   ',htm2tex(T.(tcod{i}).name)],'FontSize',8)
				end
				axis off, hold off
			end
		end

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

		% Select a color for each station which has data
		colors=[];
		n2=1;
		for n=1:length(N)
			k = D(n).G(r).k;
			if ~isempty(k)
				colors(n,:)=scolor(n2);
				n2=n2+1;
			else
				% Gray if no data
				colors(n,:)=[0.8 0.8 0.8];
			end
		end
		% loop on selected subplots
		for c = 1:length(GS)

			subplot(GS(c).subplot{:}), extaxes(gca,[.07,.01])
			cn = GS(c).chan;
			for n = 1:length(N)
				t = D(n).t;
				d = D(n).d;
				k = D(n).G(r).k;

				if any(ismember(majorslist,cn))
					k = k(ismember(d(k,i_ty),majorstype) & d(k,i_n2) <= majorsmaxn2); % selects valid data for majors
				end
				plotmark(d(k,i_ty),t(k),d(k,cn),tmkt,P.GTABLE(r).MARKERSIZE*tmks,colors(n,:))
				hold on
			end
			hold off, box on
			set(gca,'XLim',tlim,'FontSize',8)
			datetick2('x',P.GTABLE(r).DATESTR)
			ylabel(sprintf('%s %s',D(n).CLB.nm{cn},regexprep(D(n).CLB.un{cn},'(.+)','($1)')))

			% legend: station aliases
			if c == 1
				xlim = get(gca,'XLim');
				ylim = get(gca,'YLim');
				nn = length(N);
				for n = 1:nn
					text(xlim(1)+n*diff(xlim)/(nn+1),ylim(2),N(n).ALIAS,'Color',colors(n,:), ...
						'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',6,'FontWeight','bold')
				end
				set(gca,'YLim',ylim);
			end

		end

		tlabel(tlim,P.TZ)

%		% Legend for site types
%		pos = get(gca,'position');
%		axes('position',[pos(1),pos(2)+pos(4),pos(3),pos(4)/7])
%		axis([0 1 0 1]), hold on
%		for i = 1:length(tcod)
%		    plot((i-1)/length(tcod) + .05,.5,T.(tcod{i}).marker,'Markersize',P.GTABLE(r).MARKERSIZE*str2double(T.(tcod{i}).relsize),'MarkerFaceColor','k')
%		    text((i-1)/length(tcod) + .05,.5,['   ',T.(tcod{i}).name],'FontSize',8)
%		end
%		axis off, hold off

		mkgraph(WO,sprintf('_%s',P.GTABLE(r).TIMESCALE),P.GTABLE(r),struct('TYPES',T))
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
