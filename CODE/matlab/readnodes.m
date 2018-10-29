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
%
%   See READNODE for explaination of returned structure.
%
%
%   Authors: F. Beauducel, D. Lafon, WEBOBS/IPGP
%   Created: 2013-02-23
%   Updated: 2017-08-22

if nargin < 2
	error('No few input arguments')
end

NODES = readcfg(WO.CONF_NODES);

if ~iscell(grids)
	grids = cellstr(grids);
end

if nargin < 3 | isempty(tlim)
	tlim = NaN;
end

if isscalar(tlim)
	tlim = repmat(tlim,[1,2]);
end

if nargin < 4
	valid = 1;
end

N = [];
for i = 1:length(grids)
	k = 0;
	g = grids{i};
	X = dir(sprintf('%s/%s.*',WO.PATH_GRIDS2NODES,g));
	for j = 1:length(X)
		nodefullid = split(X(j).name,'.');
		% avoid duplicates
		if isempty(N) || ~any(ismember(nodefullid{3},cat(1,{N.ID})))
			NN = readnode(WO,X(j).name,NODES);
			if (~valid | NN.VALID) ...
				& (isnan(tlim(1)) | isnan(NN.END_DATE) | NN.END_DATE >= tlim(1)) ...
				& (isnan(tlim(2)) | isnan(NN.INSTALL_DATE) | NN.INSTALL_DATE <= tlim(2))
				k = k + 1;
				if isempty(N)
					N = NN;
				else
					N = structcat(N,NN);
				end
			end
		end
	end
	if nargin > 0
		fprintf('WEBOBS{readnodes}: %d/%d nodes imported from grid %s.\n',k,length(X),g);
	end
end


fprintf('WEBOBS{readnodes}: %d nodes returned.\n',length(N));


