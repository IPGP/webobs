function D=readpbo(f,varargin)
%READPBO Read PBO GPS data files.
%	D=READPBO(FILENAME) reads PBOGPS Station Position Time Series file FILENAME,
%	and returns a structure D with following fields:
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
%	Reference: https://www.unavco.org/data/gps-gnss/derived-products/docs/knowledgetree-docs-old/gps_timeseries_format.pdf
%
%	Author: François Beauducel, IPGP
%	Created: 2025-03-10 in Paris (France)

D = struct;
sraw = fileread(f);
if ~isempty(sraw)
	s = textscan(sraw,'%s',37,'CommentStyle','','Delimiter','\n');
	D.HEADER = s{1}(1:9);
	k = find(strcmp(s{1},'') | strncmp(s{1},'*YYYYMMDD',9));
	d = textscan(sraw,[repmat('%n',1,24),'%s'],'HeaderLines',k+1,'Delimiter',' ');
	D.MJD = d{:,3}; 
	D.t = D.MJD - 51545 + datenum(2000,1,1); % converts to datenum
	fn = {'X','Y','Z','Sx','Sy','Sz','Rxy','Rxz','Ryz','NLat','Elong','Height','dN','dE','dU','Sn','Se','Su','Rne','Rnu','Reu'};
	for i = 1:length(fn)
		D.(fn{i}) = d{:,i};
	end
	D.Soln = d(:,end);
end

