function P=readview(WO,view);
%READVIEW Read WEBOBS VIEW configuration
%   P = READVIEW(WO,VIEW) returns a structure variable X containing every field key and
%   corresponding value from the VIEW name configuration files.
%
%   P = READVIEW(FULL_PATH_VIEW_CNF).
%
%
%   Authors: F. Beauducel, D. Lafon, WEBOBS/IPGP
%   Created: 2013-04-05
%   Updated: 2017-08-02


if strncmp(view,'/',1)
	f = view;
else
	f = sprintf('%s/%s/%s.conf',WO.PATH_VIEWS,view,view);
end

if ~exist(f,'file')
	fprintf('WEBOBS{%s}: ** Warning: node %s does not exist.\n',mfilename,view);
	P = [];
	return
end

% reads .conf main conf file
P = readcfg(WO,f);

% split view's name
[p,view,e] = fileparts(f);

% adds SELFREF
P.SELFREF = sprintf('VIEW.%s',view);

% appends the list of nodes
% list directory WO.PATH_GRIDS2NODES for VIEW.n, appends to P as NODESLIST

D = dir(sprintf('%s/VIEW.%s.*',WO.PATH_GRIDS2NODES,n));
P.NODESLIST = {};
for j = 1:length(D)
	nj = split(D(j).name,'.');
	P.NODESLIST{end+1} = nj{3};
end 

