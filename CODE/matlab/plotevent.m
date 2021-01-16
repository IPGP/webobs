function varargout=plotevent(conf,ax)
%PLOTEVENT Display time referenced events/phases.
%	PLOTEVENT(FILE) plots shaded colored areas in the background of all axes in the
%	current figure, from the configuration FILE in the format:
%
%	   Date1|Date2|LineWidth|RGB|Name|Comment
%
%	PLOTEVENT(FILE,AX) plots only on axes AX.
%
%	FILE can be a list of coma separated files, e.g. 'events1.conf,events2.conf', in
%	that case all files are loaded and plotted together.
%
%
%   Authors: F. Beauducel + D. Lafon + B. Taisne, WEBOBS/IPGP
%   Created : 2004-07-21 (from ploterup.m)
%   Updated : 2021-01-16


wofun = sprintf('WEBOBS{%s}',mfilename);

if nargin > 0 & ~isempty(conf)
	conf = split(conf,',');
else
	varargout{1} = [];
	return;
end

if nargin < 2 || isempty(ax)
	% Detects all axes in the current figure
	ha = findobj(gcf,'Type','axes');
else
	ha = ax;
end

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
		%FB-was: [d1,d2,lw,rgb,nam,com] = textread(f,'%s%s%n%s%s%s','delimiter','|','commentstyle','shell');
		dt1 = isodatenum(data{1});
		dt2 = isodatenum(data{2});
		lw = data{3};
		rgb = data{4};
		nam = data{5};
		com = data{6};
		fprintf('WEBOBS{%s}: %s imported...',wofun,f);

		imap = 1;
		for i = 1:length(ha)
			xlim = get(ha(i),'XLim');
			ylim = get(ha(i),'YLim');
			zlim = get(ha(i),'ZLim');
			k = find(dt1 <= xlim(2) & dt2 >= xlim(1));
			if ~isempty(k)
				tk = [dt1(k),dt2(k)];
				if strcmp(get(ha(i),'YScale'),'log')
					ddy = 0;
				else
					ddy = diff(ylim)*0.005;
				end
				for ii = 1:length(k)
					x1 = max(dt1(k(ii)),xlim(1));
					x2 = min(dt2(k(ii)),xlim(2));
					y1 = ylim(1) + ddy;
					y2 = ylim(2) - ddy;
					cc = htm2rgb(rgb{k(ii)});
					axes(ha(i));
					hold on
					if x1==x2
						h = plot([x1,x2],[y1,y2],'-','LineWidth',lw(k(ii)),'Color',cc,'Clipping','on');
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
				for n = 1:length(I(imap).s)
					if length(com) >= k(n)
						sc = deblank(com{k(n)});
					else
						sc = '';
					end
					if ~isempty(sc)
						sc = sprintf('<br><i>(%s)</i>',sc);
					end
					I(imap).s{n} = sprintf('''<i>start:</i> %s<br><i>end:</i>%s%s'',CAPTION,''%s'',BGCOLOR,''%s'',CAPCOLOR,''#000000'',FGCOLOR,''#EEEEEE''', ...
						datestr(tk(n,1),'dd-mmm-yyyy HH:MM'),datestr(tk(n,2),'dd-mmm-yyyy HH:MM'),sc,nam{k(n)},rgb{k(n)});
				end
				imap = imap + 1;
				set(ha(i),'YLim',ylim,'ZLim',zlim)
			end
		end
		fprintf(' events added to current axe.\n');
	end
end

if nargout > 0
	if exist('I','var')
		varargout{1} = I;
	else
		varargout{1} = [];
	end
end
