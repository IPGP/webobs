function datetick2(varargin)
%DATETICK Date formatted tick labels. 
%   DATETICK(TICKAXIS,DATEFORM) annotates the specified tick axis with
%   date formatted tick labels. TICKAXIS must be one of the strings
%   'x','y', or 'z'. The default is 'x'.  The labels are formatted
%   according to the format number or string DATEFORM (see table
%   below).  If no DATEFORM argument is entered, DATETICK makes a
%   guess based on the data for the objects within the specified axis.
%   To produce correct results, the data for the specified axis must
%   be serial date numbers (as produced by DATENUM).
%
%   DATEFORM number   DATEFORM string         Example
%      0             'dd-mmm-yyyy HH:MM:SS'   01-Mar-2000 15:45:17 
%      1             'dd-mmm-yyyy'            01-Mar-2000  
%      2             'mm/dd/yy'               03/01/00     
%      3             'mmm'                    Mar          
%      4             'm'                      M            
%      5             'mm'                     3            
%      6             'mm/dd'                  03/01        
%      7             'dd'                     1            
%      8             'ddd'                    Wed          
%      9             'd'                      W            
%     10             'yyyy'                   2000         
%     11             'yy'                     00           
%     12             'mmmyy'                  Mar00        
%     13             'HH:MM:SS'               15:45:17     
%     14             'HH:MM:SS PM'             3:45:17 PM  
%     15             'HH:MM'                  15:45        
%     16             'HH:MM PM'                3:45 PM     
%     17             'QQ-YY'                  Q1-01        
%     18             'QQ'                     Q1        
%     19             'dd/mm'                  01/03        
%     20             'dd/mm/yy'               01/03/00     
%     21             'mmm.dd,yyyy HH:MM:SS'   Mar.01,2000 15:45:17 
%     22             'mmm.dd,yyyy'            Mar.01,2000  
%     23             'mm/dd/yyyy'             03/01/2000 
%     24             'dd/mm/yyyy'             01/03/2000 
%     25             'yy/mm/dd'               00/03/01 
%     26             'yyyy/mm/dd'             2000/03/01 
%     27             'QQ-YYYY'                Q1-2001        
%     28             'mmmyyyy'                Mar2000       
%
%   DATETICK(...,'keeplimits') changes the tick labels into date-based
%   labels while preserving the axis limits. 
%
%   DATETICK(....'keepticks') changes the tick labels into date-based labels
%   without changing their locations. Both 'keepticks' and 'keeplimits' can
%   be used at the same time.
%
%   DATETICK(AX,...) uses the specified axes, rather than the current axes.
%
%   DATETICK relies on DATESTR to convert date numbers to date strings.
%
%   Example (based on the 1990 U.S. census):
%      t = (1900:10:1990)'; % Time interval
%      p = [75.995 91.972 105.711 123.203 131.669 ...
%          150.697 179.323 203.212 226.505 249.633]';  % Population
%      plot(datenum(t,1,1),p) % Convert years to date numbers and plot
%      datetick('x','yyyy') % Replace x-axis ticks with 4 digit year labels.
%    
%   See also DATESTR, DATENUM.

%   Author(s): C.F. Garvin, 4-03-95, Clay M. Thompson 1-29-96
%   Copyright 1984-2002 The MathWorks, Inc. 
%   $Revision: 1.25 $  $Date: 2002/04/09 00:35:55 $
%
%   2009-10-07: modified by François Beauducel, IPGP to accept DATEFORM = -1

v = varargin;

if length(v) > 1
	if v{2} == -1
		v(2) = [];
	end
end

datetick(v{:});

