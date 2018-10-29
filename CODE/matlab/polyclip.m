function clippedPolygon = polyclip(subjectPolygon,clipPolygon)
%POLYCLIP Clipping polygon
%	C = POLYCLIP(A,B) returns polygon A clipped by polygon B. Inputs are 
%	a table of x-y pairs for the verticies of the subject polygon and 
%	boundary polygon (x values in column 1 and y values in column 2).
%	Both A and B boundaries must be defined counter-clockwise.
%	The output C is a table of x-y pairs for the clipped version of the 
%	subject polygon.
%
%	POLYCLIP uses the Sutherland-Hogman algorithm.
%
%	Example:
%	   A = [0,0;1,2;2,0;1,4];
%	   B = [0,1;3,1;3,3;0,3];
%	   C = polyclip(A,B);
%	   figure
%	   patch(A(:,1),A(:,2),0,'EdgeColor','b','FaceColor','none')
%	   patch(B(:,1),B(:,2),0,'EdgeColor','g','FaceColor','none')
%	   patch(C(:,1),C(:,2),0,'FaceColor','r')
%
%
%	Author: F. Beauducel / IPGP adapted from rosettacode.org
%	Created: 2015-02-10
%
%	Reference:
%	   http://rosettacode.org/wiki/Sutherland-Hodgman_polygon_clipping
 
 
%% Sutherland-Hodgman Algorithm
 
clippedPolygon = subjectPolygon;
clipVertexPrevious = clipPolygon(end,:);

for clipVertex = 1:size(clipPolygon,1)

	clipBoundary = [clipPolygon(clipVertex,:) ; clipVertexPrevious];

	inputList = clippedPolygon;

	clippedPolygon = [];
	if ~isempty(inputList),
		previousVertex = inputList(end,:);
	end

	for subjectVertex = (1:size(inputList,1))

		if ( inside(inputList(subjectVertex,:),clipBoundary) )

			if( not(inside(previousVertex,clipBoundary)) )  
				subjectLineSegment = [previousVertex;inputList(subjectVertex,:)];
				clippedPolygon(end+1,1:2) = computeIntersection(clipBoundary,subjectLineSegment);
			end

			clippedPolygon(end+1,1:2) = inputList(subjectVertex,:);

		elseif( inside(previousVertex,clipBoundary) )
			subjectLineSegment = [previousVertex;inputList(subjectVertex,:)];
			clippedPolygon(end+1,1:2) = computeIntersection(clipBoundary,subjectLineSegment);                            
		end

		previousVertex = inputList(subjectVertex,:);
		clipVertexPrevious = clipPolygon(clipVertex,:);
	end
end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function intersection = computeIntersection(line1,line2)
%computerIntersection() assumes the two lines intersect

%this is an implementation of
%http://en.wikipedia.org/wiki/Line-line_intersection

intersection = zeros(1,2);

detL1 = det(line1);
detL2 = det(line2);

detL1x = det([line1(:,1),[1;1]]);
detL1y = det([line1(:,2),[1;1]]);

detL2x = det([line2(:,1),[1;1]]);
detL2y = det([line2(:,2),[1;1]]);

denominator = det([detL1x detL1y;detL2x detL2y]);

intersection(1) = det([detL1 detL1x;detL2 detL2x]) / denominator;
intersection(2) = det([detL1 detL1y;detL2 detL2y]) / denominator;

end %computeIntersection

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function in = inside(point,boundary)
%inside() assumes the boundary is oriented counter-clockwise

pointPositionVector = [diff([point;boundary(1,:)]) 0];
boundaryVector = [diff(boundary) 0];
crossVector = cross(pointPositionVector,boundaryVector);

in = (crossVector(3) <= 0);

end
