#!/usr/bin/perl
#
# this programm uses Image::ExifTool by Phil Harvey
# download and install it: http://www.sno.phy.queensu.ca/~phil/exiftool/

use File::Copy;
use Image::ExifTool 'ImageInfo';
use File::Basename;
use File::stat;
use Time::localtime;
use Date::Parse;
use DateTime;

use constant FALSE => 0;
use constant TRUE  => 1;

# no arguments given? print help and exit
if ($#ARGV == -1) {
	print_help();
	exit(1);
}

# variables for storing command line arguments
my $dontcheckarguments = FALSE;
my $verbose = FALSE;
my $pretend = FALSE;
my $adjust = 0;

for my $fromfile (@ARGV) {

	# check for arguments
	if ($dontcheckarguments == FALSE) {
		if ($fromfile eq "-h") {
			print_help();
			next;
		} elsif ($fromfile eq "-v") {
			$verbose = TRUE;
			next;
		} elsif ($fromfile eq "-p") {
			$pretend = TRUE;
			$verbose = TRUE;
			next;
		} elsif ($fromfile =~ /^-a-?\d*/) {
            $adjust = substr($fromfile, 2);
			next;
		} elsif ($fromfile eq "--") {
			$dontcheckarguments = TRUE;
			next;
		}
	}

	# get exif creation timestamp of file
	my $info = ImageInfo($fromfile);
	my $estamp = $info->{"DateTimeOriginal"};
    my $esecs; # seconds since epoch

	# if no timestamp in file -> use mod-time of file
	if (length($estamp) != 19) {
        print "No EXIF Timestamp. Using modification time: $fromfile\n";
        $esecs = stat($fromfile)->mtime;
	} else {
        $esecs = str2time($estamp);
    }

    # eventually adjust time
    $esecs += $adjust;

	# prepare timestamp
    my $timestamp = sprintf "%4d-%02d-%02d %02d-%02d-%02d", 
            localtime($esecs)->year+1900, 
            localtime($esecs)->mon+1, 
            localtime($esecs)->mday, 
            localtime($esecs)->hour, 
            localtime($esecs)->min, 
            localtime($esecs)->sec;
	$timestamp =~ s/:/-/g;

	# cut fromfile in file's name and dir name
        $filename = basename($fromfile);
        $dirname  = dirname($fromfile);

	# strip existing timestamp from beginning of fromfile
	# (formats checked are: NNNN.NN.NN and NNNN.NN.NN.NN.NN.NN
	#  where N is a digit and . is no digit)
	$newname = $filename;
	$newname =~ s/^[0-9]{4}([^0-9][0-9]{2}){2}(([^0-9][0-9]{2}){3})?//;

	# strip delimiter characters (-_ ) from beginning of fromfile
	$newname =~ s/^(-|_| )*//;

	# check if the new name would be the same as the old name
	if ($filename eq "$timestamp $newname") {
		if ($verbose == TRUE) {
			print "name is OK, doing nothing: $fromfile\n";
		}
		next;
	}

	# rename the file

	# counter for adding a number, if the file name already exists
	$try = 0;
	while (1) {

		# build target fromfile
		if ($try == 0) {
			$filenumber = "";
		} else {
			$filenumber = "-" . $try;
		}
		$tofile = "$dirname/$timestamp$filenumber $newname";

		# test if file already exists
		if (-e "$tofile") { 
  			# increase number and do the loop again
			$try = $try + 1;
			next;
		}

		# move file
		if ($verbose == TRUE) {
			if ($pretend == TRUE) {
				print "not ";
			}
			print "renaming '$fromfile' to '$tofile'\n";
		}
		if ($pretend == FALSE) {
			move($fromfile, $tofile);
		}
		last;
	}
}

sub print_help {
	print "command line arguments:\n";
	print "  -p      pretend to rename files (implies -v)\n";
    print "  -a<sec> adjust time by <sec> seconds. can be negative\n";
	print "  -v      be verbose\n";
	print "  --      stop arguments scanning (for files named -v or the like)\n";
	print "  -h      print this help\n";
	print "\n";
	print "  hint: to recurse into subdirectories use\n";
	print "    find <pathname ...> -exec time2filename.pl -v {} \\;\n";
}
