#!/usr/bin/perl

use warnings;
use strict;

# This test script exists in the same directory
my $RDATESYNC = `cd \$(dirname $0) && pwd`;
chomp($RDATESYNC);
$RDATESYNC .= "/rdatesync.pl";

require "libtest.pl";



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


my $WORKSPACE = "/tmp/_test_sandbox";
my $BACKUP_TO_HERE = "$WORKSPACE/backups"

sub setup_test {
	&rm($WORKSPACE);
	&mkdir($WORKSPACE);
}


sub test_first_run {
	my $workspace = "/tmp/_test_sandbox";
	my $backup_to_here = "$workspace/backups";
	my $backup_dir_name = "ThisIsMyBackup";
	my $backup_this_dir = "$workspace/$backup_dir_name";
	my $backup_file_name = "aRandomFile";
	my $backup_this_file = "$backup_this_dir/$backup_file_name";
	my $test_conf = "$workspace/_test_conf";
	my $date_today = `date +%Y-%m-%d`;
	my $date_yesterday = `date --date="yesterday" +%Y-%m-%d`;
	my $date_last_month = `date --date="1 month ago" +%Y-%m-%d`;

	chomp($date_today);
	chomp($date_yesterday);
	chomp($date_last_month);

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

	open(my $cfh, '>', $test_conf) or (&rm($workspace) and &report_test_fail("Failed to open test configuration for writing"));
	print $cfh "destination $backup_to_here\n";
	print $cfh "backup $backup_this_dir\n";
	close($cfh);

	system("perl $RDATESYNC $test_conf >/dev/null 2>&1");

	if (! &assert_equal(
			&md5sum("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name"),
			&md5sum($backup_this_file))) {
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

	system("perl $RDATESYNC $test_conf >/dev/null 2>&1");

	if (! &assert_equal(
			&inode("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name"),
			&inode("$backup_to_here/daily/$date_yesterday/$backup_dir_name/$backup_file_name"))) {
		# see how badly it failed
		if (! &assert_equal(
				&md5sum("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name"),
				&md5sum($backup_this_file))) {
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
		return &report_test_fail("Failed to duplicate backups from yesterday");
	}

	&rm("$backup_to_here/daily/$date_today");
	&mv("$backup_to_here/daily/$date_yesterday", "$backup_to_here/daily/$date_last_month");

	system("perl $RDATESYNC $test_conf >/dev/null 2>&1");

	# rdatesync should move last month's dir to monthly backups
	if (! &assert_equal(
			&inode("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name"),
			&inode("$backup_to_here/monthly/$date_last_month/$backup_dir_name/$backup_file_name"))) {
		# see how badly it failed
		if (! &assert_equal(
				&md5sum("$backup_to_here/monthly/$date_today/$backup_dir_name/$backup_file_name"),
				&md5sum($backup_this_file))) {
			if (! &assert_file("$backup_to_here/monthly/$date_today/$backup_dir_name/$backup_file_name")) {
				if (! &assert_dir("$backup_to_here/monthly/$date_today/$backup_dir_name")) {
					if (! &assert_dir("$backup_to_here/monthly/$date_today")) {
						&assert_dir("$backup_to_here/monthly/")
					}
				}
			}
		}
		&rm($workspace);
		return &report_test_fail("Failed to duplicate backups from yesterday");
	}

	&rm("$backup_to_here/daily/$date_today");
	system("echo ' . int(rand(10)) . ' >> $backup_this_file");

	system("perl $RDATESYNC $test_conf >/dev/null 2>&1");

	&assert_equal(
		&md5sum($backup_this_file),
		&md5sum("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name")
	)
	&assert_not_equal(
		&md5sum("$backup_to_here/daily/$date_today/$backup_dir_name/$backup_file_name"),
		&md5sum("$backup_to_here/monthly/$date_last_month/$backup_dir_name/$backup_file_name")
	)



	&rm($workspace);
	&report_test_pass();
}



&test_first_run();

&end_tests();
