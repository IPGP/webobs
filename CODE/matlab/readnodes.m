function N=readnodes(WO,grids,tlim,valid);
%READNODES Read WEBOBS nodes of grids.
%   N = READNODES(WO,GRIDS) returns an array of structure containing every field key and
%   corresponding value from all existing valid nodes assigned to cell array of GRIDS.
%   GRIDS can be a string or an array of strings containing views or procs as
%   'GRIDtype.GRIDname'
%
%   N = READNODES(WO,GRIDS,TLIM) specifies date of node's activity. TLIM can be scalar
%   of vector in DATENUM format. Use TLIM = NOW to import only active nodes; use
%   TLIM = DATE or TLIM = [DATE1,DATE2] to get nodes active at a date DATE or in
%   period between DATE1 and DATE2.
%
%   N = READNODES(WO,GRIDS,TLIM,0) forces importation of unvalid nodes. Use TLIM = [] to
%   imports all nodes.
%
%   Note: for SEFRANS, the node list comes from the channels.conf and FDSN web-service 
%   station requests to get minimal information. This needs an additional variable in the 
%   Sefran .conf (FDSNWS_SERVER).
%
%   See READNODE for explaination of returned structure.
%
%
%   Authors: F. Beauducel, D. Lafon, WEBOBS/IPGP
%   Created: 2013-02-23
%   Updated: 2025-12-28

if nargin < 2
	error('No few input arguments')
end

wofun = sprintf('WEBOBS{%s}',mfilename);

NODES = readcfg(WO.CONF_NODES);

if ~iscell(grids)
	grids = cellstr(grids);
end

if nargin < 3 || isempty(tlim)
	tlim = NaN;
end

if isscalar(tlim)
	tlim = repmat(tlim,[1,2]);
end

if nargin < 4
	valid = 1;
end

G2N = dir(WO.PATH_GRIDS2NODES);
N = [];
for i = 1:length(grids)
	n = 0;
	g = grids{i};
    % specific case of SEFRAN
    if strncmp(g,'SEFRAN.',7)
        ss = split(g,'.');
        S3 = readcfg(WO,sprintf('/etc/webobs.d/SEFRANS/%s/%s.conf',ss{2},ss{2}));
        fdsnws = field2str(S3,'FDSNWS_SERVER');
        fid = fopen(sprintf('/etc/webobs.d/SEFRANS/%s/channels.conf',ss{2}),'rt');
            C = textscan(fid,'%q%q%q%q%q%q%q','CommentStyle','#');
        fclose(fid);
        sfr = C{2};
        k = 1:length(sfr);
        for j = 1:length(k)
            cc = split(sfr{j},'.'); % NET.STA.LOC.CHA
            NN = struct('ID',sfr{j},'NAME',sfr{j},'ALIAS',sprintf('%s.%s',cc{1},cc{2}));
            if ~isempty(fdsnws)
                fprintf('%s: get %s:%s station information from FDSNWS server %s... ',wofun,cc{1},cc{2},fdsnws);
                % FDSNWS request returns: Network|Station|Latitude|Longitude|Elevation|SiteName|StartTime|EndTime
                [s,w] = wosystem(sprintf('wget -qO- "https://%s/fdsnws/station/1/query?net=%s&sta=%s&level=station&format=text"', ...
                    fdsnws,cc{1},cc{2}));
                w = regexprep(regexprep(w,'^[^\n]*\n',''),'\n',''); % removes 1st line and last new line char
                req = textscan(w,'%s%s%s%s%s%s%s%s','delimiter','|','whitespace','');
                if ~s && length(req)==8
                    if ~isempty(req{7})
                        NN.INSTALL_DATE = datenum(req{7},'yyyy-mm-ddTHH:MM:SS');
                    else
                        NN.INSTALL_DATE = NaN;
                    end
                    if ~isempty(req{8})
                        NN.END_DATE = datenum(req{8},'yyyy-mm-ddTHH:MM:SS');
                    else
                        NN.END_DATE = NaN;
                    end
                    if (isnan(tlim(1)) || isnan(NN.END_DATE) || NN.END_DATE >= tlim(1)) ...
                        && (isnan(tlim(2)) || isnan(NN.INSTALL_DATE) || NN.INSTALL_DATE <= tlim(2))
                        NN.NAME = req{6}{:};
                        NN.ALIAS = req{2}{:};
                        NN.TZ = 0;
                        NN.LAT_WGS84 = str2num(req{3}{:});
                        NN.LON_WGS84 = str2num(req{4}{:});
                        NN.ALTITUDE = str2num(req{5}{:});
                        NN.FDSN_NETWORK_CODE = req{1}{:};
                        NN.RGB = rgb(C{6}{j});
                        n = n + 1;
                        if isempty(N)
                            N = NN;
                        else
                            N = structcat(N,NN);
                        end
                    end
                    fprintf('done.\n');
                end
            end
        end

    % standard grids (VIEW, PROC, FORM)
    else
        k = find(strncmp([g,'.'],{G2N.name},length(g)+1));
        for j = 1:length(k)
            nodefullid = split(G2N(k(j)).name,'.');
            % avoid duplicates
            if isempty(N) || ~any(ismember(nodefullid{3},cat(1,{N.ID})))
                NN = readnode(WO,G2N(k(j)).name,NODES);
                if ~isempty(NN) && (~valid || NN.VALID) ...
                    && (isnan(tlim(1)) || isnan(NN.END_DATE) || NN.END_DATE >= tlim(1)) ...
                    && (isnan(tlim(2)) || isnan(NN.INSTALL_DATE) || NN.INSTALL_DATE <= tlim(2))
                    n = n + 1;
                    if isempty(N)
                        N = NN;
                    else
                        N = structcat(N,NN);
                    end
                end
            end
        end
	end
	if nargin > 0
		fprintf('%s: %d/%d nodes imported from grid %s.\n',wofun,n,length(k),g);
	end
end

fprintf('%s: %d nodes returned.\n',wofun,length(N));
