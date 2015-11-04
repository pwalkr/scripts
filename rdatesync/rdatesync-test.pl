#!/usr/bin/perl

use warnings;
use strict;

# This test script exists in the same directory
my $RDATESYNC = `cd \$(dirname $0) && pwd`;
chomp($RDATESYNC);
$RDATESYNC .= "/rdatesync.pl";

require "libtest.pl";



sub inode {
	if (! -f $_[0]) {
		return -1;
	}
	my $inode = `/bin/ls -i $_[0]`;
	chomp($inode);
	return (split(/\s+/, $inode))[0];
}
sub md5sum {
	my $md5 = `/usr/bin/md5sum $_[0]`;
	chomp($md5);
	return (split(/\s+/, $md5))[0];
}
sub run_command {
	print "SYSTEM: $_[0]\n";
	system "$_[0] 2>&1 | sed 's/^/    /'";
}
sub mv {
	&run_command("/bin/mv -f " . join(' ', @_));
}
sub rm {
	&run_command("/bin/rm -rf " . join(' ', @_));
}



my $WORKSPACE = "/tmp/rds_sandbox";
my $DEST_DIR = "$WORKSPACE/backups";
my $TEST_CONF = "$WORKSPACE/test.conf";
my @BACKUP_DIRS = (
	"$WORKSPACE/sources/dir1",
	"$WORKSPACE/sources/nested/dir2"
);
my @BACKUP_FILES = (
	"$BACKUP_DIRS[0]/file1",
	"$BACKUP_DIRS[0]/file2",
	"$BACKUP_DIRS[1]/file3",
	"$BACKUP_DIRS[1]/subdir/file4"
);

sub run_backup {
	print "\n";
	&run_command("perl $RDATESYNC $TEST_CONF");
	print "\n";
}

sub setup {
	print "Setting up for test\n";
	system("rm -rf $WORKSPACE");

	&run_command("mkdir --parents $WORKSPACE");
	foreach (@BACKUP_FILES) {
		my $dirname = $_;
		$dirname =~ s/\/[^\/]+$//;
		&run_command("mkdir --parents $dirname");
		# Seed file with it's own path
		&run_command("echo '$_' > '$_'");
	}

	open my $cf, '>', $TEST_CONF or die "Failed to open test configuration for writing";
	print $cf "destination $DEST_DIR\n";
	foreach (@BACKUP_DIRS) {
		print $cf "backup $_\n";
	}
	close $cf;
}



sub test_first_run {
	my $workspace = "/tmp/sandbox";
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

	&run_command("mkdir -p $workspace");
	&run_command("mkdir -p $backup_this_dir");
	open(my $tfh, '>', $backup_this_file) or (&rm($workspace) and &report_test_fail("Failed to open test file for writing"));
	for (1..100) {
		print $tfh int(rand(10));
	}
	close($tfh);

	open(my $cfh, '>', $test_conf) or (&rm($workspace) and &report_test_fail("Failed to open test configuration for writing"));
	print $cfh "destination $backup_to_here\n";
	print $cfh "backup $backup_this_dir\n";
	close($cfh);

	&run_command("perl $RDATESYNC $test_conf");

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
	printf "\n";

	&run_command("perl $RDATESYNC $test_conf");

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

	&run_command("perl $RDATESYNC $test_conf");

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

	&run_command("rm -rf $backup_to_here/daily/$date_today");
	&run_command("echo ' . int(rand(10)) . ' >> $backup_this_file");

	&run_command("perl $RDATESYNC $test_conf");

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

sub test_first_backup {
	my $date_today = `date +%Y-%m-%d`;
	chomp($date_today);
	my $name;
	my $path;

	&setup();

	&run_backup();

	foreach (@BACKUP_DIRS) {
		$name = $_;
		$name =~ s/^.*\///;
		if (! &assert_dir("$DEST_DIR/daily/$date_today/$name")) {
			return &report_test_fail("Failed to produce daily backup directory");
		}
	}

	foreach (@BACKUP_FILES) {
		$name = $_;
		$name =~ s/^.*\///;
		$path = `find "$DEST_DIR/daily/$date_today" -name $name`;
		chomp($path);
		if (! &assert_not_equal($path, '')) {
			return &report_test_fail("Failed to back up file '$_'");
		}
		if (! &assert_equal(&md5sum($path), &md5sum($_))) {
			return &report_test_fail("Backup file does not match source");
		}
	}

	&report_test_pass();
}



&test_first_backup();

&end_tests();
