
ALL_TESTS=(
	"test_first_field_empty"
	"test_last_field_empty"
	"test_middle_empty"
	)


function test_first_field_empty() {
	DESCRIPTION="Empty field on the first position should be replaced by 'NaN'"

	ARGUMENTS="NODEXXX '	' 0 0"
	INPUT="	2	3	4"
	EXPECTED_OUTPUT="NaN;2;3;4"
}


function test_last_field_empty() {
	DESCRIPTION="Empty field on the last position should be replaced by 'NaN'"

	ARGUMENTS="NODEXXX '	' 0 0"
	INPUT="1	2	3	"
	EXPECTED_OUTPUT="1;2;3;NaN"
}


function test_middle_empty() {
	DESCRIPTION="Empty field on the middle should be replaced by 'NaN'"

	ARGUMENTS="NODEXXX '	' 0 0"
	INPUT="1		3	4"
	EXPECTED_OUTPUT="1;NaN;3;4"
}
