#!/usr/bin/perl

use warnings;
use strict;



my $CP = "/bin/cp";
my $RM = "/bin/rm";
my $RSYNC = "/usr/bin/rsync --archive --delete --verbose";



my $MAX_DAYS = 10;
my $MAX_MONTHS = 6;
my $BACKUP_DESTINATION = "backups";
my @BACKUP_SOURCES = ();

sub usage {
	print "Usage:\n";
	print "    rdatesync.pl <configuration file>\n";
	print "\n";
	print "    The configuration file should use the following format:\n";
	print "        destination /path/to/folder    # This is where the backups will be populated\n";
	print "        backup /folder/to/backup/name  # Any line starting with 'backup' and containing\n";
	print "                                       # a valid path will added to a list and backed up\n";
	print "                                       # in the destination folder like so:\n";
	print "                                       #     /path/to/dest/daily/yyyy-mm-dd/name\n";
	print "        mount /mount/point             # Similar to backup, multiple mount options\n";
	print "                                       # can be specified. These will be mounted prior-to\n";
	print "                                       # and disconnected from after backup.\n";
	print "                                       # NOTE: These should be specified in your fstab\n";
	print "                                       #       and mount-able by (" . `echo -n \$USER` . ")\n";
	exit;
}

sub readConf {
	my $conf_file = shift;

	my $source_dir;
	my $dest_dir;

	open(CFH, $conf_file) or die "Can't open configuration file";
	while (<CFH>) {
		if ($_ =~ /^backup\s+(.*)$/) {
			$source_dir = $1;
			# Source should NOT have trailing slash
			#     - We want to copy MyFolder/Contents, not just Contents
			$source_dir =~ s/\/?\s*$//;
			if (-d $source_dir && $source_dir !~ /\.\.|\*/) {
				push(@BACKUP_SOURCES, $source_dir);
			}
		}
		elsif ($_ =~ /^destination\s+(.*)$/) {
			$dest_dir = $1;
			chomp($dest_dir);
			if (! -d $dest_dir && $dest_dir =~ /^[\/0-9A-Za-z-._ ]+$/) {
				$BACKUP_DESTINATION = $dest_dir;
			}
			elsif (-d $dest_dir && $dest_dir !~ /\.\.|\*/) {
				$BACKUP_DESTINATION = $dest_dir;
			}
		}
	}
	close(CFH);
}
if (! -f $ARGV[0]) {
	&usage();
}
&readConf($ARGV[0]);

if ($#BACKUP_SOURCES < 0) {
	die "Must specify at least one folder to back up";
}
if (! $BACKUP_DESTINATION) {
	die "No destination folder specified";
}

my $DAILY_BACKUP_DIR = "$BACKUP_DESTINATION/daily";
my $MONTHLY_BACKUP_DIR = "$BACKUP_DESTINATION/monthly";



# printSystem: print and then run a system command
sub printSystem {
	print "$_[0]\n";
	system($_[0]);
}

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
	if (opendir my $dh, $directory) {
		while (readdir $dh) {
			$current = $_;
			next if $current =~ /\.\.?/;
			if (! &getDateInteger($current)) {
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
		closedir($dh);
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
chomp($date_today);

my ($newest_daily, $oldest_daily, $count_daily) = &parse_backups($DAILY_BACKUP_DIR);
my ($newest_monthly, $oldest_monthly, $count_monthly) = &parse_backups($MONTHLY_BACKUP_DIR);

if ($newest_daily) {
	$RSYNC .= " --link-dest=$DAILY_BACKUP_DIR/$newest_daily";
}
elsif ($newest_monthly) {
	$RSYNC .= " --link-dest=$DAILY_BACKUP_DIR/$newest_monthly";
}

if (-d "$DAILY_BACKUP_DIR/$date_today") {
	print "It looks like backup has already run for today\n";
	exit 0;
}

system("mkdir -p '$DAILY_BACKUP_DIR/$date_today'");
foreach (@BACKUP_SOURCES) {
	$RSYNC .= " '$_'";
}
&printSystem("$RSYNC '$DAILY_BACKUP_DIR/$date_today'");
$newest_daily = $date_today;
$count_daily++;

# If the newest daily starts a new month, copy it to monthly.
if (0 eq $newest_monthly or &getMonth($newest_daily) ne &getMonth($newest_monthly)) {
	if (! -e "$MONTHLY_BACKUP_DIR/$newest_daily") {
		print "Copying $DAILY_BACKUP_DIR/$newest_daily to $MONTHLY_BACKUP_DIR/\n";
		system("$CP --recursive --link '$DAILY_BACKUP_DIR/$newest_daily' '$MONTHLY_BACKUP_DIR/'");
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
