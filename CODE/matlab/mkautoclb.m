function CLB = mkautoclb(N,nm,un)
%MKAUTOCLB make an automatic CLB file
%   MKAUTOCLB(N,NAME,UNIT) makes an automatic calibration file for node N
%   (structure from readnode.m) from cell arrays of strings NAME and UNIT
%   (same length).
%
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2024-05-06 in Paris (France) 
%   Updated: 2025-04-19

if nargin < 3 || length(nm) ~= length(un)
    un = repmat({''},size(nm));
    error('NAME and UNIT arrays must have the same length. Use empty units.')
end

w = wosystem('echo "$(whoami)@$(hostname)"','chomp','print');
nx = length(nm);

if nx > 0
    f = sprintf('%s_auto.clb',N.FULLID);
    fid = fopen(sprintf('%s/%s/%s',N.WO.PATH_NODES,N.ID,f),'wt');
        fprintf(fid,'# WEBOBS - %s: auto-generated calibration file %s\n',N.WO.WEBOBS_ID,N.FULLID);
        fprintf(fid,'# [%s %s]\n',datestr(now),w);
        fprintf(fid,'=key|DATE|TIME|nv|nm|un|ns|cd|of|et|ga|vn|vm|az|la|lo|al|dp|sf|db|lc\n');
        for n = 1:nx
            fprintf(fid,'%d|%s|00:00|%d|%s|%s|||0|1|1|||0|%g|%g|%g|||||\n', ...
                n,datestr(N.INSTALL_DATE,'yyyy-mm-dd'),n,nm{n},un{n},N.LAT_WGS84,N.LON_WGS84,N.ALTITUDE);
        end
    fclose(fid);
    fprintf('auto-generated calibration file %s written (%d channels).\n',f,nx);
end

CLB = struct('nx',nx,'dt',0,'nv',0,'nm',0,'un',0,'ns',0,'cd',0, ...
             'of',0,'et',0,'ga',0,'vn',0,'vm',0,'az',0, ...
             'la',0,'lo',0,'al',0,'dp',0,'sf',0,'db',0,'lc',0);
CLB.dt = repmat(N.INSTALL_DATE,1,nx);
CLB.nv = 1:nx;
CLB.nm = nm;
CLB.un = un;
CLB.ns = repmat({''},1,nx);
CLB.cd = repmat({''},1,nx);
CLB.of = zeros(1,nx);
CLB.et = repmat({'1'},1,nx);
CLB.ga = ones(1,nx);
CLB.vn = nan(1,nx);
CLB.vm = nan(1,nx);
CLB.az = zeros(1,nx);
CLB.la = repmat(N.LAT_WGS84,1,nx);
CLB.lo = repmat(N.LON_WGS84,1,nx);
CLB.al = repmat(N.ALTITUDE,1,nx);
CLB.dp = zeros(1,nx);
CLB.sf = nan(1,nx);
CLB.db = repmat({''},1,nx);
CLB.lc = repmat({''},1,nx);
