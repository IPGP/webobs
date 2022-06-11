function X=readnodeevent(file)
%READNODEEVENT Read a node event
%   READNODEEVENT(FILE) reads a node event from FILE (full path) and returns a
%   structure with fields:
%           id: node ID
%	     date1: start date/time (datenum format)
%	     date2: end date/time (datenum format)
%       author: authors' UID list
%	     title: title string
%	   comment: event content string
%      feature: associated node feature
%       sensor: associated node sensor
%	   outcome: sensor outcome flag
%	  notebook: notebook number
%	     nbfwd: notebook forward flag
%
%    Author: F. Beauducel, in Saint-Pierre, La Réunion
%   Created: 2022-06-11

% event name = NODEID_YYYY-MM-DD_HH-MM.txt
evtname = split(regexprep(regexprep(file,'.txt$',''),'^.*/',''),'_');
X.id = evtname{1};
X.date1 = datenum(sprintf('%s %s',evtname{2},regexprep(evtname{3},'-',':')));
if exist(file,'file')
    ss = split(fileread(file),'\n');
    % event header = authors|title|datetime2|feature|sensor|outcome|notebook|notebookfwd
    evthead = split(ss{1},'|');
    if length(evthead) > 2
        X.date2 = datenum(evthead{3});
    else
        X.date2 = X.date1;
    end
    X.author = evthead{1};
    X.title = evthead{2};
    X.comment = ss(2:end);
    if length(evthead) > 3
        X.feature = evthead{4};
    end
    if length(evthead) > 4
        X.sensor = evthead{5};
    end
    if length(evthead) > 5
        X.outcome = str2num(evthead{6})>0;
    end
    if length(evthead) > 6
        X.notebook = evthead{7};
    end
    if length(evthead) > 7
        X.nbfwd = str2num(evthead{8})>0;
    end
end
