#!/usr/bin/perl

use warnings;
use strict;

# This test script exists in the same directory
my $RDATESYNC = `cd \$(dirname $0) && pwd`;
chomp($RDATESYNC);
$RDATESYNC .= "/rdatesync.pl";

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
	return 10;
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
	my $left = shift;
	my $right = shift;
	if ($left ne $right) {
		return &report_assert_fail("'$left' ne '$right'");
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



sub mv {
	system("/bin/mv -f " . join(' ', @_));
}
sub inode {
	my $inode = `/bin/ls -i $_[0]`;
	chomp($inode);
	return (split(/\s+/, $inode))[0];
}
sub md5sum {
	my $md5 = `/usr/bin/md5sum $_[0]`;
	chomp($md5);
	return (split(/\s+/, $md5))[0];
}
sub mkdir {
	system("/bin/mkdir -p " . join(' ', @_));
}
sub rm {
	system("/bin/rm -rf " . join(' ', @_));
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

	&assert_equal(1, '1');
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

	&rm($test_file);
	&assert_file($test_file) and return &report_test_fail("System failed to remove test file");
	$fail_count++;
	&assert_not_file($test_file) or return &report_test_fail("System failed to remove test file");
	$pass_count++;

	my $test_dir = "_test_directory";
	&assert_dir($test_dir) and return &report_test_fail("Test directory exists already");
	$fail_count++;
	&assert_not_dir($test_dir) or return &report_test_fail("Test directory exists already");
	$pass_count++;

	&mkdir($test_dir);
	&assert_dir($test_dir) or return &report_test_fail("System failed to create test directory");
	$pass_count++;
	&assert_not_dir($test_dir) and return &report_test_fail("System failed to create test directory");
	$fail_count++;

	&rm($test_dir);
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

	return &report_test_pass();
}
&test_sanity() or die "Test suite failed sanity check";



sub test_first_run {
	my $workspace = "/tmp/_test_sandbox";
	my $backup_to_here = "$workspace/backups";
	my $backup_dir_name = "ThisIsMyBackup";
	my $backup_this_dir = "$workspace/$backup_dir_name";
	my $backup_file_name = "aRandomFile";
	my $backup_this_file = "$backup_this_dir/$backup_file_name";
	my $file_md5sum;
	my $test_conf = "$workspace/_test_conf";
	my $date_today = `date +%Y-%m-%d`;
	my $date_yesterday = `date --date="yesterday" +%Y-%m-%d`;

	chomp($date_today);
	chomp($date_yesterday);

	&assert_not_dir($workspace) or &report_test_fail("Test workspace already present");

	&assert_match($RDATESYNC, 'rdatesync.pl$');
	&assert_file($RDATESYNC);

	&mkdir($workspace);
	&mkdir($backup_this_dir);
	open(my $tfh, '>', $backup_this_file) or (&rm($workspace) and &report_test_fail("Failed to open test file for writing"));
	for (1..100) {
		print $tfh int(rand(10));
	}
	close($tfh);
	$file_md5sum = &md5sum($backup_this_file);

	open(my $cfh, '>', $test_conf) or (&rm($workspace) and &report_test_fail("Failed to open test configuration for writing"));
	print $cfh "destination $backup_to_here\n";
	print $cfh "backup $backup_this_dir\n";
	close($cfh);

	system("perl $RDATESYNC $test_conf >/dev/null 2>&1");

	if (! &assert_equal(&md5sum("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name"), $file_md5sum)) {
		# see how badly it failed
		if (! &assert_file("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name")) {
			if (! &assert_dir("$backup_to_here/daily/$date_today/$backup_dir_name")) {
				if (! &assert_dir("$backup_to_here/daily/$date_today")) {
					if (! &assert_dir("$backup_to_here/daily/")) {
						&assert_dir("$backup_to_here")
					}
				}
			}
		}
		&rm($workspace);
		return &report_test_fail("Failed to create first backup");
	}

	&mv("$backup_to_here/daily/$date_today", "$backup_to_here/daily/$date_yesterday");

	system("perl $RDATESYNC $test_conf 2>&1 | sed 's/^/    /'");

	if (! &assert_equal(
			&inode("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name"),
			&inode("$backup_to_here/daily/$date_yesterday/$backup_dir_name/$backup_file_name"))) {
		# see how badly it failed
		if (! &assert_equal(&md5sum("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name"), $file_md5sum)) {
			if (! &assert_file("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name")) {
				if (! &assert_dir("$backup_to_here/daily/$date_today/$backup_dir_name")) {
					if (! &assert_dir("$backup_to_here/daily/$date_today")) {
						if (! &assert_dir("$backup_to_here/daily/")) {
							&assert_dir("$backup_to_here")
						}
					}
				}
			}
		}
		&rm($workspace);
		return &report_test_fail("Failed to seed today's backup from yesterday");
	}



	&rm($workspace);
	&report_test_pass();
}



print "Sanity test passed\n\n";
&test_first_run();


$FATAL_ERROR = 0;

exit;
