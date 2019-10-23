
ALL_TESTS=(
	"test_discard_comments"
	"test_discard_headers"
	"test_additional_separators"
	)


function test_discard_comments() {
	DESCRIPTION="Lines starting with % or # should be discarded"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="# This is a comment
% this is a comment too
1,2,3,4"
	EXPECTED_OUTPUT="1;2;3;4"
}


function test_discard_headers() {
	DESCRIPTION="The third argument specifies the number of header lines to discard"

	ARGUMENTS="NODEXXX ',' 2 0"
	INPUT='"col1","col2","col3"
"Avg","Samp","Samp"
1,2,3,4'
	EXPECTED_OUTPUT="1;2;3;4"
}


function test_additional_separators() {
	DESCRIPTION=""

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="
1,2,3,4"
	EXPECTED_OUTPUT="1;2;3;4"
}
