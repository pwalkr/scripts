#!/usr/bin/perl

use warnings;
use strict;

my $TEST_PASS = 0;
my $TEST_FAIL = 0;
my $ASSERT_FAIL = 0;
my $ASSERT_PASS = 0;
# Flag for if we bail out before all tests
my $FATAL_ERROR = 1;

END {
	print "\n";
	print "Test success: $TEST_PASS\n";
	print "Test failure: $TEST_FAIL\n";
	print "Assert pass: $ASSERT_PASS\n";
	print "Assert fail: $ASSERT_FAIL\n";

	if ($FATAL_ERROR) {
		print "\nTests aborted due to a fatal error\n";
	}
}

sub report_test_pass {
	$TEST_PASS++;
	return 1;
}
sub report_test_fail {
	print "Test failed: $_[0]\n";
	$TEST_FAIL++;
	return 0;
}
sub report_assert_pass {
	$ASSERT_PASS++;
	return 1
}
sub report_assert_fail {
	print "Assert failed: $_[0]\n";
	$ASSERT_FAIL++;
	return 0
}
sub assert_equal {
	if ($#_ < 0) {
		return &report_assert_pass();
	}
	my $left = shift;
	if ($#_ < 0) {
		return &report_assert_fail("'$left' ne ''");
	}
	my $right = shift;
	if ($left ne $right) {
		return &report_assert_fail("'$left' ne '$right'");
	}
	return &report_assert_pass();
}
sub assert_not_equal {
	if ($#_ < 0) {
		return &report_assert_pass();
	}
	my $left = shift;
	if ($#_ < 0) {
		return &report_assert_fail("'$left' eq ''");
	}
	my $right = shift;
	if ($left eq $right) {
		return &report_assert_fail("'$left' eq '$right'");
	}
	return &report_assert_pass();
}
sub assert_file {
	my $file = shift;
	if (! -f $file) {
		return &report_assert_fail("'$file' is not a file");
	}
	return &report_assert_pass();
}
sub assert_not_file {
	my $file = shift;
	if (-f $file) {
		return &report_assert_fail("'$file' is a file");
	}
	return &report_assert_pass();
}
sub assert_dir {
	my $dir = shift;
	if (! -d $dir) {
		return &report_assert_fail("'$dir' is not a directory");
	}
	return &report_assert_pass();
}
sub assert_not_dir {
	my $dir = shift;
	if (-d $dir) {
		return &report_assert_fail("'$dir' is a directory");
	}
	return &report_assert_pass();
}
sub assert_match {
	my $string = shift;
	my $regex = shift;
	if ($string !~ /$regex/) {
		return &report_assert_fail("'$string' !~ '$regex'");
	}
	return &report_assert_pass();
}



sub test_sanity {
	my $pass_copy = $ASSERT_PASS;
	my $fail_copy = $ASSERT_FAIL;
	my $pass_count = 0;
	my $fail_count = 0;
	my $final_pass;
	my $final_fail;

	# Generate some assert success and failures
	&assert_equal(1, 1);
	$pass_count++;
	&assert_not_equal(1, 1);
	$fail_count++;

	&assert_equal(1, '1');
	$pass_count++;
	&assert_not_equal(1, '1');
	$fail_count++;

	&assert_not_equal(1, 'one');
	$pass_count++;
	&assert_equal(1, 'one');
	$fail_count++;

	my $test_file = "_test_file";
	&assert_file($test_file) and return &report_test_fail("Test files exists already");
	$fail_count++;
	&assert_not_file($test_file) or return &report_test_fail("Test files exists already");
	$pass_count++;

	system("touch $test_file");
	&assert_file($test_file) or return &report_test_fail("System failed to create test file");
	$pass_count++;
	&assert_not_file($test_file) and return &report_test_fail("System failed to create test file");
	$fail_count++;

	system("rm -f $test_file");
	&assert_file($test_file) and return &report_test_fail("System failed to remove test file");
	$fail_count++;
	&assert_not_file($test_file) or return &report_test_fail("System failed to remove test file");
	$pass_count++;

	my $test_dir = "_test_directory";
	&assert_dir($test_dir) and return &report_test_fail("Test directory exists already");
	$fail_count++;
	&assert_not_dir($test_dir) or return &report_test_fail("Test directory exists already");
	$pass_count++;

	system("mkdir $test_dir");
	&assert_dir($test_dir) or return &report_test_fail("System failed to create test directory");
	$pass_count++;
	&assert_not_dir($test_dir) and return &report_test_fail("System failed to create test directory");
	$fail_count++;

	system("rm -rf $test_dir");
	&assert_dir($test_dir) and return &report_test_fail("System failed to remove test directory");
	$fail_count++;
	&assert_not_dir($test_dir) or return &report_test_fail("System failed to remove test directory");
	$pass_count++;

	$final_pass = $ASSERT_PASS;
	$final_fail = $ASSERT_FAIL;

	&assert_equal($final_pass, $pass_copy + $pass_count) or return &report_test_fail("assert success does not match");
	&assert_equal($final_fail, $fail_copy + $fail_count) or return &report_test_fail("assert failure does not match");

	$ASSERT_PASS = $pass_copy;
	$ASSERT_FAIL = $fail_copy;

	return 1;
}
&test_sanity() or die "Test suite failed sanity check";
print "Sanity test passed\n\n";
