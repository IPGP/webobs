function X = graphstr(s)
%GRAPHSTR Graph string interpreter
%	GRAPHSTR(S) interprets the char string S and return an array structure X
%	with fields:
%	   X(n).chan : channel number for graph n
%	   X(n).size : size of the graph n (positive integer)
%	   X(n).type : vector of graph type string (not functional)
%	   X(n).subplot : cell of arguments for the subplot function.
%
%	Examples:
%	   '1,2,3' means channels 1,2 and 3 on 3 equal size subplots
%	   '2,,,1,3,10,11,,' means channels 2, 1, 3, 10 and 11 with channel 2
%	   three times higher and channel 11 two times higher in size than others.
%
%	To get the total graph size use sum(cat(1,X.size)).
%
%
%	Authors: F. Beauducel / WEBOBS, IPGP
%	Created: 2016-08-05, in Paris (France)
%	Updated: 2020-12-28


% splits the graphs (coma separated)
x = split(regexprep(s,'[^0-9,]',''),',');

if ~isempty(x)
	k = find(~cellfun(@isempty,x));
	ng = length(k);

	k = [k,length(x)+1];

	for n = 1:ng
		X(n).chan = str2num(x{k(n)});
		X(n).size = k(n+1) - k(n);
		X(n).type = regexprep(x{k(n)},'[0-9]','');
	end

	% set the subplot arguments (doubles the height size)
	tot = 2*sum(cat(1,X.size));
	sp = 0;
	for n = 1:ng
		X(n).subplot = {tot,1,sp + (1:2*X(n).size)};
		sp = 2*sum(cat(1,X(1:n).size));
	end
else
	X = [];
end
