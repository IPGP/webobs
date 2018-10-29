function varargout = readcombined(x)

varargout = {'seedlink',x{1},'arclink',x{2}};

for i = 1:2
	k = strfind(x{i},'://');
	if ~isempty(k)
		varargout{i*2} = x{i}(k(1)+3:end);
		fmt = x{i}(1:k(1)-1);
		switch fmt
		case 'slink'
			varargout{i*2 - 1} = 'seedlink';
		case 'arclink'
			varargout{i*2 - 1} = 'arclink';
		case 'fdsnws'
			varargout{i*2 - 1} = 'fdsnws-dataselect';
		case 'file'
			varargout{i*2 - 1} = 'miniseed';
		end
	end
end
