function state = checkereaderfile(file)

% Check for the integrity of EReader files
% state = 0 when all seems OK (i.e. file reading OK and values lower than limit=
% state = 1 when values out of limit are found
% state = 2 for failure of reading

limit = 10^5; % Just a huge value to detect octet misalignment
try
    D = readudbf(file);
    state = ~isempty(find(abs(D.data) > limit)); % Are there bad values ?
%     disp(['Try: state = ' num2str(state)])
catch
    state = 2; % The reading above failed
%     disp(['Catch: state = ' num2str(state)])
end
disp([num2str(state)]);
%end
