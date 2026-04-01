function txt = tlim2str(tlim)

    s = cell(1,2);
    for i = 1:2
        if isnan(tlim(i))
            s{i} = 'NaN';
        else
            s{i} = datestr(tlim(i));
        end
    end
    txt = sprintf('%s to %s',s{:});
