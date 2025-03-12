function D=readpbopos(f,varargin)
%READPBOPOS Read PBO GPS station position files.
%	D=READPBOPOS(FILENAME) reads PBO Station Position Time Series file FILENAME,
%	(.pos) and returns a structure D with following fields:
%	      HEADER: sub-structutre containing header values as strings
%	         MJD: Modified Julian Day
%	           t: datetime vector (datenum format)
%	       X,Y,Z: geocentric coordinates (in m)
%	    Sx,Sy,Sz: standard deviation of X,Y,Z positions (in m)
%	 Rxy,Rxz,Ryz: correlation of XY,XZ,YZ position pairs
%	  NLat,Elong: North latitude, East longitude, WGS84 ellipsoid, decimal degrees
%	      Height: Height relative to WGS84 ellipsoid (in m)
%	    dN,dE,dU: Difference in North,East,Up component from NEU reference position (in m)
%	    Sn,Se,Su: Standard deviation of dN,dE,dU (in m)
%	 Rne,Rnu,Reu: Correlation of dN/dE,dN/dU,dE/dU pairs
%	        Soln: "rapid" ,"final", "suppl/suppf", "campd", or "repro" products
%
%	Reference: https://www.unavco.org/data/gps-gnss/derived-products/docs/NOTICE-TO-DATA-PRODUCT-USERS-GPS-2013-03-15.pdf
%
%	Author: François Beauducel, IPGP
%	Created: 2025-03-10 in Paris (France)
%   Updated: 2025-03-12

D = struct;
sraw = fileread(f);
if ~isempty(sraw)
	s = textscan(sraw,'%s',37,'CommentStyle','','Delimiter','\n');
	% full header stored as cell of strings
    D.HEADER = s{1}(1:9);
    % extract header info
    D.FormatVersion = value(s{1}{2}); 
    D.ID = value(s{1}{3});
    D.StationName = value(s{1}{4});
    D.FirstEpoch = datenum(value(s{1}{5}),'yyyymmdd HHMMSS');
    D.LastEpoch = datenum(value(s{1}{6}),'yyyymmdd HHMMSS');
    D.ReleaseDate = datenum(value(s{1}{7}),'yyyymmdd HHMMSS');
    ss = strsplit(value(s{1}{8}),' ');
    D.XYZReferencePosition = str2double(ss(1:3));
    if length(ss) > 3
        D.XYZReferenceFrame = regexprep(ss{4},'[()]','');
    end
    ss = strsplit(value(s{1}{9}),' ');
    D.NEUReferencePosition = str2double(ss(1:3));
    if length(ss) > 3
        D.NEUReferenceFrame = regexprep(ss{4},'[()]','');
    end
    % finds start of the data table
	k = find(strcmp(s{1},'') | strncmp(s{1},'*YYYYMMDD',9))
	d = textscan(sraw,['%15c',repmat('%n',1,22),'%s%[^\n]'],'HeaderLines',k);
	D.t = datenum(d{1},'yyyymmdd HHMMSS');
	fn = {'MJD','X','Y','Z','Sx','Sy','Sz','Rxy','Rxz','Ryz','NLat','Elong','Height','dN','dE','dU','Sn','Se','Su','Rne','Rnu','Reu','Soln'};
	for i = 1:length(fn)
		D.(fn{i}) = d{i+1};
	end
end

function v=value(s)
    ss = strsplit(s,':');
    v = strtrim(ss{2});