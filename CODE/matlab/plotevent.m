function varargout=plotevent(tz,evtfile,evt)
%PLOTEVENT Display time referenced events/phases.
%	PLOTEVENT(TZ,FILE) plots shaded colored areas in the background of all axes in the
%	current figure, considering X-axis as UT date/time datenum format, from the
%	configuration FILE in the format:
%
%	   Date1|Date2|LineWidth|RGB|Name|Comment
%
%	where Date1 and Date2 are UT date & time strings in ISO format (yyyy-mm-dd HH:MM:SS)
%	and TZ is time zone in hours from GMT. 
%	
%	PLOTEVENT(TZ,FILE,EVENTS) plots additionnal events from structure EVENTS.
%
%	FILE can be a list of comma separated files, e.g. 'events1.conf,events2.conf', in
%	that case all files are loaded and plotted together.
%
%
%   Authors: F. Beauducel + D. Lafon + B. Taisne, WEBOBS/IPGP
%   Created : 2004-07-21 (from ploterup.m)
%   Updated : 2024-06-13


wofun = sprintf('WEBOBS{%s}',mfilename);

if isnan(tz) || ~isnumeric(tz)
	tz = 0;
end

E = [];
if nargin > 1 & ~isempty(evtfile)
	conf = split(evtfile,',');
	for n = 1:length(conf)
		% if filename is local (no directory), considers it in ROOT_CONF for backward compatibility
		if isempty(strfind(conf{n},'/'))
			f = sprintf('/etc/webobs.d/%s',conf{n});
		else
			f = conf{n};
		end
		fid = fopen(f);
		if fid == -1
			fprintf('%s: ** WARNING ** file %s cannot be opened.\n',wofun,f);
		else
			data = textscan(fid,'%s%s%n%s%s%s','Delimiter','|','CommentStyle','#');
			fclose(fid);
			if size(data{1},1) == 0
				fprintf('%s: ** WARNING ** file %s is empty.\n',wofun,f);
			else
				E(n).dt1 = isodatenum(data{1});
				E(n).dt2 = isodatenum(data{2});
				E(n).lw = data{3};
				E(n).rgb = rgb(data{4});
				E(n).hex = rgb2hex(E(n).rgb);
				E(n).nam = data{5};
				E(n).com = data{6};
				E(n).out = false(size(data{1}));
				fprintf('%s: %s imported...',wofun,f);
			end
		end
	end
end

if nargin > 2 && isstruct(evt)
	if numel(E) > 0
		E = cat(2,evt,E);
	else
		E = evt;
	end
end

if numel(E) == 0
	varargout{1} = [];
	return;
end

% Detects all axes in the current figure with empty UserData
ha = findobj(gcf,'Type','axes');

imap = 1;
for n = 1:numel(E)
	% converts event time in the graph time zone
	E(n).dt1 = E(n).dt1 + tz/24;
	E(n).dt2 = E(n).dt2 + tz/24;

	for i = 1:length(ha)
		if ~isempty(get(ha(i),'UserData'))
			break
		end
		xlim = get(ha(i),'XLim');
		ylim = get(ha(i),'YLim');
		zlim = get(ha(i),'ZLim');
		k = find(E(n).dt1 <= xlim(2) & E(n).dt2 >= xlim(1));
		if ~isempty(k)
			tk = [E(n).dt1(k),E(n).dt2(k)];
			if strcmp(get(ha(i),'YScale'),'log')
				ddy = 0;
			else
				ddy = diff(ylim)*0.005;
			end
			for ii = 1:length(k)
				x1 = max(E(n).dt1(k(ii)),xlim(1));
				x2 = min(E(n).dt2(k(ii)),xlim(2));
				y1 = ylim(1) + ddy;
				y2 = ylim(2) - ddy;
				cc = E(n).rgb(k(ii),:);
				axes(ha(i));
				hold on
				if x1 == x2
					h = plot([x1,x2],[y1,y2],'-','LineWidth',E(n).lw(k(ii)),'Color',cc,'Clipping','on');
				else
					%h = fill3([x1,x1,x2,x2],[y1,y2,y2,y1],-ones([1,4]),cc);
					h = patch([x1,x1,x2,x2],[y1,y2,y2,y1],cc);
					set(h,'EdgeColor','none','Clipping','on');
				end
				hold off
				% puts in the background
				hc = get(ha(i),'Children');
				set(ha(i),'Children',hc([2:end,1]));
				%set(ha(i),'Children',flipud(hc));

			end
			I(imap).d = [tk(:,1),repmat(ylim(2),length(k),1),tk(:,2),repmat(ylim(1),length(k),1)];
			I(imap).gca = gca;
			I(imap).s = cell(length(k),1);
			I(imap).l = cell(length(k),1);
			for ii = 1:length(k)
				sn = regexprep(regexprep(E(n).nam{k(ii)},'"','&quot;'),'''','&rsquo;');
				if length(E(n).com) >= k(ii)
					sc = deblank(E(n).com{k(ii)});
				else
					sc = '';
				end
				if ~isempty(sc)
					sc = sprintf('<br><i>(%s)</i>',sc);
				end
				sc = regexprep(regexprep(sc,'"','&quot;'),'''','&rsquo;');
				I(imap).s{ii} = sprintf('''<i>start:</i> %s<br><i>end:</i> %s%s'',CAPTION,''%s'',BGCOLOR,''%s'',CAPCOLOR,''#000000'',FGCOLOR,''#EEEEEE''', ...
					datestr(tk(ii,1),'dd-mmm-yyyy HH:MM'),datestr(tk(ii,2),'dd-mmm-yyyy HH:MM'),sc,sn,E(n).hex{k(ii)});
			end
			imap = imap + 1;
			set(ha(i),'YLim',ylim,'ZLim',zlim)
		end
	end
	fprintf(' events added to all time series axes in current figure.\n');
end

if nargout > 0
	if exist('I','var')
		varargout{1} = I;
	else
		varargout{1} = [];
	end
end
