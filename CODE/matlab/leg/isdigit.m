function k=isdigit(s)
%ISDIGIT True for digit characters.
%       For a string S, ISDIGIT(S) is 1 for numeric characters (digits of 
%       integer numbers only) and 0 otherwise.
%
%       See also ISLETTER and ISSPACE.
%
%       (c) F. Beauducel, OVSG 2001.

k = (s>='0' & s<='9');