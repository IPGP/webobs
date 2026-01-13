function status = mkexport(WO,f,E,P,r,N);
%MKEXPORT PROC's exporting data as TXT file.
%	MKEXPORT(WO,F,E,P,R) exports data E:
%	   E.t = time vector (DATENUM format)
%	   E.d = data matrix (numeric)
%	   E.header = headers (cell of strings)
%	   E.fmt = format printf (cell of strings)
%	   E.title = title (string)
%	   E.infos = multi-line comments (cell of strings)
%	in the file F.txt using:
%      - PROC parameters from structure P,
%      - GTABLE parameters from P.GTABLE(R) where R is the index of TIMESCALES table.
%
%   File header is completed by additional infos from P using the variable
%   P.EXPORT_HEADER_PROC_KEYLIST.
% 
%   MKEXPORT(WO,F,E,P,N) adds further infos in the file header using NODE 
%   structure N and P.EXPORT_HEADER_NODE_KEYLIST variable.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2003-03-10
%	Updated: 2026-01-13


ptmp = sprintf('%s/%s/%s',WO.PATH_TMP_WEBOBS,P.SELFREF,randname(16));
wosystem(sprintf('mkdir -p %s',ptmp));

if isfield(P.GTABLE(r),'EVENTS')
	pout = sprintf('%s/%s/%s',P.GTABLE(r).OUTDIR,WO.PATH_OUTG_EVENTS,P.GTABLE(r).EVENTS);
else
	pout = sprintf('%s/%s',P.GTABLE(r).OUTDIR,WO.PATH_OUTG_EXPORT);
end

if ~isfield(E,'fmt')
	E.fmt = repmat({'%f'},[1,size(E.d,2)]);
end

proc_keylist = split(field2str(P,'EXPORT_HEADER_PROC_KEYLIST',''),',');
node_keylist = split(field2str(P,'EXPORT_HEADER_NODE_KEYLIST',''),',');	

wosystem(sprintf('mkdir -p %s',pout));

fprintf('WEBOBS{mkexport}: updating %s/%s.txt ... ',pout,f);
ftmp = sprintf('%s/%s.txt',ptmp,f);
fid = fopen(ftmp,'wt');
if fid > 0

    % Main header
	fprintf(fid,'%s\n',repmat('#',[1,80]));
	fprintf(fid,'# %s\n#\n',WO.WEBOBS_TITLE);
	fprintf(fid,'# PROC: {%s} %s\n',P.SELFREF,P.NAME);
	fprintf(fid,'# TITLE: %s\n',E.title);
	fprintf(fid,'# FILENAME: %s.txt\n',f);
	if ~isnan(P.GTABLE(r).DATE1) && ~isnan(P.GTABLE(r).DATE2)
		fprintf(fid,'# TIMESPAN: from "%s" to "%s"\n',datestr(P.GTABLE(r).DATE1),datestr(P.GTABLE(r).DATE2));
	else
		fprintf(fid,'# TIMESPAN: all data\n');
	end
	fprintf(fid,'#\n');

    % Header node keylist
    if nargin > 5 && isstruct(N)
        for f = 1:length(node_keylist)
            fprintf(fid,'# NODE.%s: %s\n',node_keylist{f},field2str(N,node_keylist{f}));
        end
    end

    % Header proc keylist
    for f = 1:length(proc_keylist)
        fprintf(fid,'# PROC.%s: %s\n',proc_keylist{f},field2str(P,proc_keylist{f}));
    end
    fprintf(fid,'#\n');

    % Specific header infos
	if isfield(E,'infos')
		for i = 1:length(E.infos)
			fprintf(fid,'#   %s\n',E.infos{i});
		end
	end
	[s,w] = wosystem('echo "$(whoami)@$(hostname)"','chomp');
	if ~s
		fprintf(fid,'#\n# CREATED: %s by %s\n',datestr(now),w);
	end
	fprintf(fid,'# COPYRIGHT: %s, %s\n',num2roman(str2num(datestr(now,'yyyy'))),P.COPYRIGHT);
	fprintf(fid,'%s\n',repmat('#',[1,80]));
	fprintf(fid,'#\n');
	fprintf(fid,'#yyyy mm dd HH MM SS');
	for i = 1:length(E.header)
		fprintf(fid,' %s',E.header{i});
	end
	fprintf(fid,'\n');

	% to avoid sprintf's rounding of seconds (59.999 -> 60)
	tv = datevec(E.t);
	if all(tv(:,6)==ceil(tv(:,6)))
		sfmt = '%02.f';
	else
		sfmt = '%06.3f';
		tv(:,6) = ceil(tv(:,6)*1e3)/1e3;
	end
	fprintf(fid,['%4d %02d %02d %02d %02d ',sfmt,sprintf(' %s',E.fmt{:}),'\n'],[tv,E.d]');

	fclose(fid);

	wosystem(sprintf('mv -f %s %s/.',ftmp,pout));
	fprintf('done.\n');
else
	fprintf('** WARNING ** cannot create file !\n',ftmp);
end

% removes the temporary directory
wosystem(sprintf('rm -rf %s',ptmp));
