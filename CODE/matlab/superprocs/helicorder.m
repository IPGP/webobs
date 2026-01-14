function DOUT=helicorder(varargin)
%HELICORDER WebObs SuperPROC: Helicorders for single channel time series.
%
%       HELICORDER(PROC) makes default outputs (events type) of a helicorder PROC.
%
%       HELICORDER(PROC,TSCALE) updates all or a selection of TIMESCALES for data import:
%           TSCALE = '%' : all timescales defined by PROC.conf (default)
%	    TSCALE = '01y' or '30d,10y,'all' : only specified timescales
%	    (keywords must be in TIMESCALELIST of PROC.conf)
%
%	HELICORDER(PROC,[],REQDIR) makes graphs/exports for specific request directory REQDIR.
%	REQDIR must contain a REQUEST.rc file with dedicated parameters.
%
%       D = HELICORDER(PROC,...) returns a structure D containing all the PROC data:
%           D(i).id = node ID
%           D(i).t = time vector (for node i)
%           D(i).d = matrix of processed data (NaN = invalid data)
%
%       HELICORDER will use PROC's parameters from .conf file. Particularily, it
%       uses RAWFORMAT and and nodes' calibration file channels definition to select
%       channels and display names and units.
%
%       HELICORDER makes a graph per channel of each node, one per day over the TSCALE time period.
%
%       Specific paramaters are:
%          HELICORDER_DURATION_DAYS|1
%          HELICORDER_TURNS|24*4
%          HELICORDER_SCALE|100
%          HELICORDER_PAPER_COLOR|white
%          HELICORDER_TRACE_COLOR|black,red,mediumblue,green
%	   HELICORDER_YTICK_HOURS|1
%	   HELICORDER_RADIUS|1
%	   HELICORDER_TOPDOWN|N
%	   HELICORDER_TITLE|{\fontsize{14}\bf$node_alias: $node_name - $stream_name}
%          PICKS_CLEAN_PERCENT|0
%          FLAT_IS_NAN|NO
%          UNDERSAMPLING|Y
%
%	List of internal variables that will be substituted in text strings:
%	   $node_name      = node long name
%	   $node_alias     = node alias
%	   $stream_name    = full stream name (NET:STA:CHA:LOC)
%
%
%
%	Authors: F. Beauducel, J.-M. Saurel / WEBOBS, IPGP
%	Created: 2016-12-30 in Yogyakarta, Indonesia
%	Updated: 2025-12-04

WO = readcfg;
wofun = sprintf('WEBOBS{%s}',mfilename);

% --- checks input arguments
if nargin < 1
	error('%s: must define PROC name.',wofun);
end

proc = varargin{1};
procmsg = any2str(mfilename,varargin{:});
timelog(procmsg,1);

% gets PROC's configuration, associated nodes for any TSCALE and/or REQDIR (without loading the data)
[P,N] = readproc(WO,varargin{:});

% event mode: only the first TSCALE is considered
r = 1;

hd = field2num(P,'HELICORDER_DURATION_DAYS',1);
ht = field2num(P,'HELICORDER_TURNS',24*4);
hscale = field2num(P,'HELICORDER_SCALE',100);
hscaleref = field2num(P,'HELICORDER_SCALE_REF');
hpaper = field2num(P,'HELICORDER_PAPER_COLOR',rgb('white'));
hcolors = rgb(regexprep(split(field2str(P,'HELICORDER_TRACE_COLOR'),','),' ',''));
hytick = field2num(P,'HELICORDER_YTICK_HOURS',1);
hradius = field2num(P,'HELICORDER_RADIUS',1);
htrend = isok(P,'HELICORDER_TREND');
htopdown = isok(P,'HELICORDER_TOPDOWN');
htitle = field2str(P,'HELICORDER_TITLE','{\fontsize{14}\bf$node_alias: $node_name - $stream_name}');
papersize = field2num(P,'PAPERSIZE',[8,11]);
fontsize = field2num(P,'FONTSIZE',8);

for n = 1:length(N)

	V.node_name = N(n).NAME;
	V.node_alias = N(n).ALIAS;

	% ===================== loops on TSCALE period with DURATION_DAYS steps

	for t0 = floor(P.GTABLE(r).DATE1/hd)*hd:hd:floor(P.GTABLE(r).DATE2/hd)*hd

		tlim = t0 + [0,hd];

        P.DATELIM = tlim;
        % reads the data for time period only
        [D,P] = readfmtdata(WO,P,N);

        C = D(n).CLB;
        nx = C.nx;
        % compute the scales over whole period TSCALE
        scale = 1e10*ones(1,nx);
        for c = 1:nx
            dd = diff(D(n).d(:,c));
            dd(isnan(dd)) = [];
            mstd = median(abs(dd - median(dd)));
            scale(c) = 1e10;
            if hscaleref > 0
                scale(c) = hscale*ht*hscaleref;
            else
                if ~isnan(mstd) && mstd ~= 0
                    scale(c) = hscale*ht*mstd;
                end
            end
        end
		k = find(isinto(D(n).t,tlim));
		tk = [];
		dk = nan(0,nx);
		ke = [];
		if ~isempty(k)
			[tk,dk] = treatsignal(D(n).t(k),D(n).d(k,:),P.GTABLE(r).DECIMATE,P);
			ke = k(end);
		end
		vtps = datevec(tlim(1));
		P.GTABLE(r).EVENTS = sprintf('%4d/%02d/%02d/%s',vtps(1:3),N(n).ID);
		pdat = sprintf('%s/%s/%s',P.GTABLE(1).OUTDIR,WO.PATH_OUTG_EVENTS,P.GTABLE(1).EVENTS);

		% loop for each data channel
		for c = 1:nx

			fnam = sprintf('%4d%02d%02dT%02d%02d%02.0f_%s_%s_%s_%s',vtps,N(n).FDSN_NETWORK_CODE,N(n).FID,C.cd{c},C.lc{c});
			fdat = sprintf('%s/%s.png',pdat,fnam);
			V.stream_name = sprintf('%s:%s:%s:%s',N(n).FDSN_NETWORK_CODE,N(n).FID,C.cd{c},C.lc{c});

			% makes graph if image does not exist or image is older than data
			% does not make any graph in case of empty data
			if ~isempty(k) && (~exist(fdat,'file') || (filedate(fdat,P.TZ) < tlim(2) && tlim(1) >= P.DATELIM(1)))

				xlim = [0,hd/ht];
				ylim = [0,1 + htrend/ht] - .5/ht;

				figure
				orient tall
				axes
				set(gca,'XLim',xlim,'YLim',ylim,'TickDir','out','FontSize',fontsize,'XMinorTick','on')
				if ~strcmp(hpaper,'white')
					%whitebg(gcf,[0.05,0.05,0.1])
					h = rectangle('position',[xlim(1),ylim(1),diff(xlim),diff(ylim)]);
					set(h,'FaceColor',hpaper);
					set(gca,'Color','k')
				end
				pos = get(gca,'Position');
				if htopdown
					set(gca,'YDir','reverse','XAxisLocation','top','Position',[pos(1),pos(2)-.03,pos(3:4)]);
				else
					set(gca,'Position',[pos(1),pos(2)-.01,pos(3:4)]);
				end
				hold on

				for tt = 0:(ht-1)
					tt0 = t0 + tt*hd/ht;
					kk = isinto(tk,tt0 + [0,hd/ht]);
					if any(kk)
						x = tk(kk)-tt0;
						y = (dk(kk,c)-median(dk(kk,c)))/scale(c) + tt/ht;
						galvaplot(x,y + htrend*x/x(end)/ht,[hd/ht,1,hradius],'-', ...
							'LineWidth',P.GTABLE(r).MARKERSIZE/10,'Color',hcolors(1+mod(tt,size(hcolors,1)),:))
					end
				end
				hold off
				box on
				extaxes(gca,.07/(1 + .5*(papersize(1)>papersize(2))));
				datetick2('x')
				ytick = linspace(0,1-hytick/24,hd*24/hytick);
				set(gca,'YTick',ytick,'YTickLabel',datestr(ytick*hd,'HH:MM'))
				% Y-label at right position
				text(repmat(xlim(2),size(ytick)),ytick,datestr((ytick + 1/ht)*hd,'    HH:MM'),'Color',.01*[1,1,1], ...
					'FontSize',fontsize,'Clipping','off')

				% title, status and additional information
				P.GTABLE(r).GTITLE = varsub(htitle,V);
				P.GTABLE(r).GSTATUS = [P.NOW,D(n).G(r).last,D(n).G(r).samp];
				P.GTABLE(r).INFOS = {''};
				if ~isempty(k)
					P.GTABLE(r).INFOS = {' ','Last data:',sprintf('{\\bf%s} {\\it%+d}',datestr(D(n).t(ke)),P.TZ), ...
					' ',' ', ...
					sprintf('Time span: {\\bf%s - %s} {\\it%+g}',datestr(tlim(1),0),datestr(tlim(2),0),P.TZ), ...
					' ',' ',' ', ...
                    ['Scale = ' repmat('auto',~(hscaleref>0)) repmat(sprintf('%g %s',hscaleref,C.un{c}),hscaleref>0) sprintf(' (\\times %g)',hscale)], ...
					sprintf('Median STD = %g %s',mstd,C.un{c}), ...
					' ',' ', ...
					};
				end

				% makes graph
				mkgraph(WO,fnam,P.GTABLE(r))
				close

				% creates symbolic links to preferred (last) files
				for ext = {'jpg','png'}
					wosystem(sprintf('ln -sf %s.%s %s/heli.%s',fnam,ext{:},pdat,ext{:}),P);
				end

			end

		end
	end

	% creates symbolic links to today and yesterday date directory
	dte = datestr(floor(P.GTABLE(r).DATE2),'YYYY/mm/dd');
	wosystem(sprintf('ln -sfn %s/%s %s/%s/today_%s',dte,N(n).ID,P.GTABLE(1).OUTDIR,WO.PATH_OUTG_EVENTS,N(n).ID),P);
	dte = datestr(floor(P.GTABLE(r).DATE2)-1,'YYYY/mm/dd');
	wosystem(sprintf('ln -sfn %s/%s %s/%s/yesterday_%s',dte,N(n).ID,P.GTABLE(1).OUTDIR,WO.PATH_OUTG_EVENTS,N(n).ID),P);
end



if P.REQUEST
	mkendreq(WO,P);
end

timelog(procmsg,2)


% Returns data in DOUT
if nargout > 0
	DOUT = D;
end
