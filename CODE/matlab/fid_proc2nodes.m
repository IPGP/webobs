function varargout=fid_proc2nodes(P,N)
%FID_PROC2NODES Propagates FID's from proc to nodes
%   N=FID_PROC2NODES(P,N) returns structure of nodes N after adding or replacing
%   any empty FID's with default FID_* variables, defined and unempty, in the
%   proc structure P.

pf = fieldnames(P);
fid = pf(strncmp(pf,'FID_',4));
for f = 1:length(fid)
    if ~isempty(P.(fid{f}))
        for n = 1:length(N)
            if ~isfield(N(n),fid{f}) || isempty(N(n).(fid{f}))
                N(n).(fid{f}) = P.(fid{f});
            end
        end
    end
end

varargout{1} = N;
