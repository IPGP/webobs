
ALL_TESTS=(
	"test_space_is_separator"
	"test_double_spaces_are_trimed"
	"test_slash_is_separator"
	"test_colon_is_separator"
	"test_tab_is_separator"
	"test_hyphen_is_separator"
	"test_hyphen_is_ignored_before_digits"
	)


function test_space_is_separator() {
	DESCRIPTION="A space anywhere in an input line will introduce a new column"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="1 2,3,4"
	EXPECTED_OUTPUT="1;2;3;4"
}


function test_double_spaces_are_trimed() {
	DESCRIPTION="Double spaces are trimmed before being splitted"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="1  2,3,4"
	EXPECTED_OUTPUT="1;2;3;4"
}


function test_slash_is_separator() {
	DESCRIPTION="A slash anywhere in an input line will introduce a new column"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="1/2,3,4"
	EXPECTED_OUTPUT="1;2;3;4"
}


function test_colon_is_separator() {
	DESCRIPTION="A colon anywhere in an input line will introduce a new column"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="1:2,3,4"
	EXPECTED_OUTPUT="1;2;3;4"
}


function test_tab_is_separator() {
	DESCRIPTION="A tabulation anywhere in an input line will introduce a new column"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="1	2,3,4"
	EXPECTED_OUTPUT="1;2;3;4"
}


function test_hyphen_is_separator() {
	DESCRIPTION="An hyphen anywhere in an input line will introduce a new column
	unless it is present before any digit"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="1-2,3,4"
	EXPECTED_OUTPUT="1;2;3;4"
}


function test_hyphen_is_ignored_before_digits() {
	DESCRIPTION="An hyphen is ignored if it is present before any digit"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="1,-2,3,4"
	EXPECTED_OUTPUT="1;-2;3;4"
}
