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
sub assert_dir {
	my $dir = shift;
	if (! -d $dir) {
		return &report_assert_fail("'$dir' is not a directory");
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

	&assert_equal(1, '1');
	$pass_count++;

	&assert_equal(1, 'one');
	$fail_count++;

	my $test_file = "_test_file";
	&assert_file($test_file) and return &report_test_fail("Test files exists already");
	$fail_count++;
	system("touch $test_file");
	&assert_file($test_file) or return &report_test_fail("System failed to create test file");
	$pass_count++;
	system("rm -f $test_file");
	&assert_file($test_file) and return &report_test_fail("System failed to remove test file");
	$fail_count++;

	my $test_dir = "_test_directory";
	&assert_dir($test_dir) and return &report_test_fail("Test directory exists already");
	$fail_count++;
	system("mkdir $test_dir");
	&assert_dir($test_dir) or return &report_test_fail("System failed to create test directory");
	$pass_count++;
	system("rmdir $test_dir");
	&assert_dir($test_dir) and return &report_test_fail("System failed to remove test directory");
	$fail_count++;

	$final_pass = $ASSERT_PASS;
	$final_fail = $ASSERT_FAIL;

	&assert_equal($final_pass, $pass_copy + $pass_count) or return &report_test_fail("assert success does not match");
	&assert_equal($final_fail, $fail_copy + $fail_count) or return &report_test_fail("assert failure does not match");

	$ASSERT_PASS = $pass_copy;
	$ASSERT_FAIL = $fail_copy;

	return &report_test_pass();
}

sub test_first_run {
	my $backup_destination = "/tmp/backups";
	&assert_match($RDATESYNC, 'rdatesync.pl$');
	&assert_file($RDATESYNC);
}

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



&test_sanity() or die "Test suite failed sanity check";
&test_first_run();


$FATAL_ERROR = 0;

exit;




my $BACKUP_DESTINATION = "backups";

my $MAX_DAYS = 10;
my $MAX_MONTHS = 6;



my $DAILY_BACKUP_DIR = "$BACKUP_DESTINATION/daily";
my $MONTHLY_BACKUP_DIR = "$BACKUP_DESTINATION/monthly";

my $CP = "/bin/cp";
my $RM = "/bin/rm";
my $RSYNC = "/usr/bin/rsync";




sub readConf {
	my $conf_file = shift;
	open(CFH, $conf_file) or die "Can't open configuration file";
	close(CFH);
}
#&readConf($ARGV[0]);


# Compress yyyy-mm-dd into yyyymmdd for integer comparisons
sub getDateInteger {
	my $date_string = shift;
	my $date_int = 0;
	if ($date_string =~ /([0-9]{4})-([0-9]{2})-([0-9]{2})/) {
		$date_int = int "$1$2$3";
	}
	return $date_int;
}

# Count folders in a backup directory and return (newest, oldest, count)
sub parse_backups {
	my $directory = $_[0];
	my $count = 0;
	my $current;
	my $oldest = 0;
	my $newest = 0;
	if (open my $dh, $directory) {
		while (<$dh>) {
			$current = $_;
			if (! &getDateInteger()) {
				print "Unrecognized backup folder: $current\n";
				next;
			}

			if (! $oldest || &getDateInteger($current) < &getDateInteger($oldest)) {
				$oldest = $current;
			}
			if (! $newest || &getDateInteger($current) > &getDateInteger($newest)) {
				$newest = $current;
			}
			$count++;
		}
		close($dh);
	}
	return ($newest, $oldest, $count);
}

sub getMonth {
	my $date_string = shift;
	if ($date_string =~ /[0-9]{4}-([0-9]{2})-[0-9]{2}/) {
		return $1;
	}
	print "Unrecognized date string: $date_string\n";
}

my $date_today = `date +%Y-%m-%d`;

my ($newest_daily, $oldest_daily, $count_daily) = &parse_backups($DAILY_BACKUP_DIR);
my ($newest_monthly, $oldest_monthly, $count_monthly) = &parse_backups($MONTHLY_BACKUP_DIR);

print "$DAILY_BACKUP_DIR/$date_today\n";
if (! -d "$DAILY_BACKUP_DIR/$date_today") {
	if ($newest_daily) {
		print "Seeding new backup of $date_today from $newest_daily\n";
		system("cd '$DAILY_BACKUP_DIR' && $CP --archive --link '$newest_daily' '$date_today'");
		$count_daily++;
	}
}
else {
	print "It looks like backup has already run for today\n";
	exit 0;
}

my $source_directory = "Pictures"; #something input from config
my $source_name = "Pictures"; #something input from config
# TODO: Think about: if source already exists in backup, duplicate backup?
#     should use rsync --link-dest instead of a blind cp?

# Source should NOT have trailing slash
#     - We want to copy MyFolder/Contents, not just Contents
$source_directory =~ s/\/?\s*$//;

#system(
print(
	"$RSYNC"
	. " --archive"
	. " --delete"
	. " --verbose"
	. " '$source_directory'"
	. " '$DAILY_BACKUP_DIR/$date_today/$source_name'"
	. "\n"
);
exit;



# If the oldest daily starts a new month, copy it to monthly.
if (&getMonth($oldest_daily) ne &getMonth($newest_monthly)) {
	if (! -e "$MONTHLY_BACKUP_DIR/$oldest_daily") {
		print "Copying $DAILY_BACKUP_DIR/$oldest_daily to $MONTHLY_BACKUP_DIR/";
		system("$CP --archive --link '$DAILY_BACKUP_DIR/$oldest_daily' '$MONTHLY_BACKUP_DIR/'");
		$count_monthly++;
	}
}

while ($count_daily > $MAX_DAYS) {
	print "Removing $DAILY_BACKUP_DIR/$oldest_daily\n";
	system("$RM --recursive --force '$DAILY_BACKUP_DIR/$oldest_daily'");
	($newest_daily, $oldest_daily, $count_daily) = &parse_backups($DAILY_BACKUP_DIR);
}
while ($count_monthly > $MAX_MONTHS) {
	print "Removing $MONTHLY_BACKUP_DIR/$oldest_monthly\n";
	system("$RM --recursive --force '$MONTHLY_BACKUP_DIR/$oldest_monthly'");
	($newest_monthly, $oldest_monthly, $count_monthly) = &parse_backups($MONTHLY_BACKUP_DIR);
}
