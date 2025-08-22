function E = add_export_metadata(E, NP, export_header_keylist, np_type)
%ADD_EXPORT_METADATA Add metadata to export structure based on node and process parameters
%
% INPUTS:
%   E - Export structure to modify
%   NP - Node or Proc configuration structure
%   export_header_keylist - Cell array of node/proc field names to export
%   np_type - String indicating the type ('NODE' or 'PROC')
%
% OUTPUT:
%   E - Modified export structure with added metadata

    % Initialize meta field if it doesn't exist
    if ~isfield(E, 'meta')
        E.meta = struct();
    end
    
    % Add node metadata
    if ~isempty(export_header_keylist)
        for iexport = 1:length(export_header_keylist)
            fieldname = export_header_keylist{iexport};
            if isfield(NP, fieldname) 
                E.meta.([np_type, '.', fieldname]) = any2str(NP.(fieldname));
            end
        end
    end
end