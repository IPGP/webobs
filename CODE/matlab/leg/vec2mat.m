function [mat,padded] = vec2mat(vec,matcol)
%VEC2MAT Convert a vector into a matrix
%   MAT = VEC2MAT(VEC,MATCOL) converts the vector vec into a matrix with matcol columns,
%   creating one row at a time. If the length of vec is not a multiple of matcol, then 
%   extra zeros are placed in the last row of mat. The matrix mat has ceil(length(vec)/matcol) rows.
%
%   [MAT,PADDED] = VEC2MAT(...) returns an integer padded that indicates how many extra entries
%   were placed in the last row of mat.
%
%   Author: F. Beauducel, OVSG, based on the description of VEC2MAT function of Mathworks Communication Toolbox
%   Created: 2004-03-19
%   Modified: 2004-03-19


r = ceil(length(vec)/matcol);
z = zeros(r*matcol - length(vec),1);
mat = reshape([vec(:);z],[matcol,r])';
padded = length(z);