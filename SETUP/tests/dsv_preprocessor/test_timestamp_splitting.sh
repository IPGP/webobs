
ALL_TESTS=(
	"test_timestamp_format10"
	"test_timestamp_format11"
	"test_timestamp_format12"
	"test_timestamp_format13"
	"test_timestamp_format14"

	"test_timestamp_format20"
	"test_timestamp_format30"
	"test_timestamp_format40"
	)


# ISO 8601 format -------------------------------------------------------------


function test_timestamp_format10() {
	DESCRIPTION="Date in a format similar to ISO 8601 with no timezone should be correctly splitted"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="2006-08-14T02:34:56,1,2,3"
	EXPECTED_OUTPUT="2006;08;14;02;34;56;1;2;3"
}


function test_timestamp_format11() {
	DESCRIPTION="Date in a ISO 8601 format with timezone 'Z' should be correctly splitted
	but UTC indicator is lost"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="2006-08-14T02:34:56Z,1,2,3"
	EXPECTED_OUTPUT="2006;08;14;02;34;56;1;2;3"
}


function test_timestamp_format12() {
	DESCRIPTION="Nanoseconds in ISO 8601 format are currently not splitted"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="2006-08-14 02:34:56.123Z,1,2,3"
	EXPECTED_OUTPUT="2006;08;14;02;34;56.123;1;2;3"
}


function test_timestamp_format13() {
	DESCRIPTION="Timezone negative sign in ISO 8601 format is lost but timezone splitted"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="2006-08-14 02:34:56.123-06:00,1,2,3"
	EXPECTED_OUTPUT="2006;08;14;02;34;56.123;06;00;1;2;3"
}


function test_timestamp_format14() {
	DESCRIPTION="Timezone positive sign in ISO 8601 format is retained but timezone is not splitted"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="1937-01-01T12:00:27.87+00:20,1,2,3"
	EXPECTED_OUTPUT="1937;01;01;12;00;27.87+00;20;1;2;3"
}


# Other formats ---------------------------------------------------------------


function test_timestamp_format20() {
	DESCRIPTION="Hyphen-separated date is correctly splitted"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="2006-08-14 02:34,1,2,3"
	EXPECTED_OUTPUT="2006;08;14;02;34;1;2;3"
}


function test_timestamp_format30() {
	DESCRIPTION="Slash-separated date is correctly splitted"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="2006/08/14 02:34,1,2,3"
	EXPECTED_OUTPUT="2006;08;14;02;34;1;2;3"
}


function test_timestamp_format40() {
	DESCRIPTION="Hyphen-separated date with day of year is correctly splitted"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="2006-226 02:34,1,2,3"
	EXPECTED_OUTPUT="2006;226;02;34;1;2;3"
}
