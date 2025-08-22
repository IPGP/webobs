function outstruct = add_export_metadata(NP, export_header_keylist, np_type)
%ADD_EXPORT_METADATA Add metadata to export structure based on node and process parameters
%
% INPUTS:
%   NP - Node or Proc configuration structure
%   export_header_keylist - Cell array of node/proc field names to export
%   np_type - String indicating the type ('NODE' or 'PROC')
%
% OUTPUT:
%   outstruct - export structure with added metadata

    % Initialize meta field if it doesn't exist
    outstruct = struct();
    
    % Add node metadata
    if ~isempty(export_header_keylist)
        for iexport = 1:length(export_header_keylist)
            fieldname = export_header_keylist{iexport};
            outstruct.([np_type,'.', fieldname]) = any2str(NP.(fieldname));
        end
    end
end

