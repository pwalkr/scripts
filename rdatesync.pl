#!/usr/bin/perl

use warnings;
use strict;

my $BACKUP_DESTINATION = "backups";

my $MAX_DAYS = 10;
my $MAX_MONTHS = 6;



my $DAILY_BACKUP_DIR = "$BACKUP_DESTINATION/daily";
my $MONTHLY_BACKUP_DIR = "$BACKUP_DESTINATION/monthly";

my $CP = "/bin/cp";
my $RM = "/bin/rm";
my $RSYNC = "/usr/bin/rsync";






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
	if (open my $dh $directory) {
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

if (! -e "$DAILY_BACKUP_DIR/$date_today") {
	print "Seeding new backup of $date_today from $newest_daily\n"
	system("cd '$DAILY_BACKUP_DIR' && $CP --archive --link '$newest_daily' '$date_today'")
	$count_daily++;
}
else {
	print "It looks like backup has already run for today\n";
	exit 0;
}

my $source_directory = "" #something input from config
# TODO: Think about: if source already exists in backup, duplicate backup?
#     should use rsync --link-dest instead of a blind cp?

# Source should NOT have trailing slash
#     - We want to copy MyFolder/Contents, not just Contents
$source_directory =~ s/\/?\s*$//;

system(
	"$RSYNC"
	. " --archive"
	. " --delete"
	. " --verbose"
	. " '$source_directory'"
	. " '$DAILY_BACKUP_DIR/$date_today'"
);



# If the oldest daily starts a new month, copy it to monthly.
if (&getMonth($oldest_daily) -ne &getMonth($newest_monthly)) {
	if (! -e "$MONTHLY_BACKUP_DIR/$oldest_daily") {
		print "Copying $DAILY_BACKUP_DIR/$oldest_daily to $MONTHLY_BACKUP_DIR/"
		system("$CP --archive --link '$DAILY_BACKUP_DIR/$oldest_daily' '$MONTHLY_BACKUP_DIR/'")
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
