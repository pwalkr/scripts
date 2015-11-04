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

sub test_second_backup {
	my $date_today = `date +%Y-%m-%d`;
	my $date_yesterday = `date --date="yesterday" +%Y-%m-%d`;
	chomp($date_today);
	chomp($date_yesterday);
	my $name;
	my $tpath;
	my $ypath;

	&setup();

	&run_backup();

	&assert_dir("$DEST_DIR/daily/$date_today") or return &report_test_fail("Failed to make a first backup");
	&run_command("mv $DEST_DIR/daily/$date_today $DEST_DIR/daily/$date_yesterday");

	&run_backup();

	foreach (@BACKUP_FILES) {
		$name = $_;
		$name =~ s/^.*\///;
		$tpath = `find "$DEST_DIR/daily/$date_today" -name $name`;
		$ypath = `find "$DEST_DIR/daily/$date_yesterday" -name $name`;
		chomp($tpath, $ypath);
		if (! &assert_equal(&inode($tpath), &inode($ypath))) {
			return &report_test_fail("Backup failed to copy inode for file");
		}
	}

	&report_test_pass();
}



&test_first_backup();
&test_second_backup();

&end_tests();
