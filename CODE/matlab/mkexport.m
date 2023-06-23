function status = mkexport(WO,f,E,G);
%MKEXPORT PROC's exporting data as TXT file.
%	MKEXPORT(WO,F,E,G) exports data E:
%	   E.t = time vector (DATENUM format)
%	   E.d = data matrix (numeric)
%	   E.header = headers (cell of strings)
%	   E.fmt = format printf (cell of strings)
%	   E.title = title (string)
%	   E.infos = multi-line comments (cell of strings)
%	in the file F.txt using PROCS parameters defined in structure G.
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2003-03-10
%	Updated: 2019-06-10


ptmp = sprintf('%s/%s/%s',WO.PATH_TMP_WEBOBS,G.SELFREF,randname(16));
wosystem(sprintf('mkdir -p %s',ptmp));

%DL p = WO.PATH_OUTPUT_MATLAB;

if isfield(G,'EVENTS')
	pout = sprintf('%s/%s/%s',G.OUTDIR,WO.PATH_OUTG_EVENTS,G.EVENTS);
else
	pout = sprintf('%s/%s',G.OUTDIR,WO.PATH_OUTG_EXPORT);
end

if ~isfield(E,'fmt')
	E.fmt = repmat({'%f'},[1,size(E.d,2)]);
end

wosystem(sprintf('mkdir -p %s',pout));

fprintf('WEBOBS{mkexport}: updating %s/%s.txt ... ',pout,f);
ftmp = sprintf('%s/%s.txt',ptmp,f);
fid = fopen(ftmp,'wt');
if fid > 0

	fprintf(fid,'%s\n',repmat('#',[1,80]));
	fprintf(fid,'# %s\n#\n',WO.WEBOBS_TITLE);
	fprintf(fid,'# PROC: {%s} %s\n',G.SELFREF,G.NAME);
	fprintf(fid,'# TITLE: %s\n',E.title);
	fprintf(fid,'# FILENAME: %s.txt\n',f);
	if ~isnan(G.DATE1) && ~isnan(G.DATE2)
		fprintf(fid,'# TIMESPAN: from %s to %s\n',datestr(G.DATE1),datestr(G.DATE2)); 
	end
	fprintf(fid,'#\n'); 
	if isfield(E,'infos')
		for i = 1:length(E.infos)
			fprintf(fid,'#   %s\n',E.infos{i}); 
		end
	end
	[s,w] = wosystem('echo "$(whoami)@$(hostname)"','chomp');
	if ~s
		fprintf(fid,'#\n# CREATED: %s by %s\n',datestr(now),w); 
	end
	fprintf(fid,'# COPYRIGHT: %s, %s\n',datestr(now,'yyyy'),G.COPYRIGHT);
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

