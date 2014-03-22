#!/usr/bin/perl

# Convert movie subtitles from SRT format and MicroDVD .sub format to
# ELAN annotations (EAF file format).

# Please note there's more than one subtitle format that uses the .sub
# extension. If it's not MicroDVD format, it will certainly not work
# with this script.

# lari.lampen@mpi.nl, 2010

use strict;


# --- Read input ---
if ($#ARGV < 0) {
    die "Usage: perl sub2eaf.pl subtitlefile [framerate]";
}
my $infile=$ARGV[0];
open IF,$infile || die "Failed to open file";
my @lines=<IF>;
chomp @lines;
close IF;
my $framerate=25;
if ($#ARGV > 0) {
    $framerate=$ARGV[1];
}

my $prefix=$infile;
$prefix =~ s/\.[^\.]*$//;
my $vid_url="file://$prefix.mp4";
my $wav_url="file://$prefix.wav";


# --- Start file (print header) ---
preamble();


# --- Process data and print list of timeslots ---

my @contents;
my @ids;
my $counter=1;

if ($infile =~ /\.sub/) {
    process_subfile();
} elsif ($infile =~ /\.srt/) {
    process_srtfile();
} else {
    die "Unknown file extension.";
}


# --- Print list of annotations ---
print "  <TIER TIER_ID=\"subtitle\" LINGUISTIC_TYPE_REF=\"utterance\" DEFAULT_LOCALE=\"en\">\n";
$counter=1;
while ($#contents>=0) {
    my $content=shift(@contents);
    my $id="a$counter";
    my $start=shift(@ids);
    my $end=shift(@ids);

    print "    <ANNOTATION>\n";
    print "      <ALIGNABLE_ANNOTATION ANNOTATION_ID=\"$id\" TIME_SLOT_REF1=\"$start\" TIME_SLOT_REF2=\"$end\">\n";
    print "        <ANNOTATION_VALUE>$content</ANNOTATION_VALUE>\n";
    print "      </ALIGNABLE_ANNOTATION>\n";
    print "    </ANNOTATION>\n";
    $counter++;
}
print "  </TIER>\n";


# --- End file ---
endmatter();





# ----- subroutines -----

# Convert frame count to milliseconds.
sub frame2ms {
    my $fc=shift;
    return int($fc * 1000/$framerate);
}

# Convert "hh:mm:ss,ms" to milliseconds. 
sub hms2ms {
    my $t=shift;
    my @fields=split(/[:,]/,$t);
    
    return strip0($fields[3])
	+1000*strip0($fields[2])
	+60*1000*strip0($fields[1])
	+60*60*1000*strip0($fields[0]);
}
    
sub strip0 {
    my ($in)=@_;
    $in =~ s/^0+//;
    return $in;
}

# Read in subtitles in MicroDVD .sub format.
sub process_subfile {
    print "  <TIME_ORDER>\n";
    foreach my $line(@lines) {
	# Take off CRLF endline. This is nasty and should do a proper
	# check.
	chop $line;
	$line =~ /{(.*)}{(.*)}(.*)/;
	my $start=$1;
	my $end=$2;
	my $content=$3;
	$content =~ s/\|/ /g;
	my $id="ts$counter";
	print_timeslot(frame2ms($start));
	print_timeslot(frame2ms($end));
	push @contents, $content;
    }
    print "  </TIME_ORDER>\n";
}


# Read in subtitles in SRT format.
sub process_srtfile {
    print "  <TIME_ORDER>\n";
    my ($start, $end, $content);
    foreach my $line(@lines) {
	# Take off CRLF endline. This is nasty and should do a proper
	# check.
	chop $line;

	if ($line eq "") {
	    # Empty line: one record is ready, save it.
	    print_timeslot(hms2ms($start));
	    print_timeslot(hms2ms($end));
	    push @contents, $content;
	    $start="";
	    $end="";
	    $content="";
	} elsif ($start eq "") {
	    # Extract start and end times.
	    next unless $line =~ /(.*) --> (.*)/;
	    $start=$1;
	    $end=$2;
	} else {
	    # Save the content. Remember it may span multiple lines.
	    if ($content eq "") {
		$content=$line;
	    } else {
		$content .= " ".$line;
	    }
	}
    }
    print "  </TIME_ORDER>\n";
}


# Print time slot and store the time slot id in @ids.
sub print_timeslot {
    my ($time)=@_;
    my $id="ts$counter";

    print "    <TIME_SLOT TIME_SLOT_ID=\"$id\" TIME_VALUE=\"",
          int($time), "\"/>\n";
    push @ids, $id;
    $counter++;
}

sub preamble {
print <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<ANNOTATION_DOCUMENT xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.mpi.nl/tools/elan/EAFv2.5.xsd" DATE="2008-03-19T16:07:44+00:00" AUTHOR="" VERSION="2.5" FORMAT="2.5">
  <HEADER MEDIA_FILE="" TIME_UNITS="milliseconds">
    <MEDIA_DESCRIPTOR MEDIA_URL="$vid_url" MIME_TYPE="video/mpeg" RELATIVE_MEDIA_URL="$vid_url"/>
<!--    <MEDIA_DESCRIPTOR MEDIA_URL="$wav_url" MIME_TYPE="audio/x-wav" RELATIVE_MEDIA_URL="$wav_url" EXTRACTED_FROM="file://elan-example1.mpg"/>   -->
    <PROPERTY NAME="lastUsedAnnotationId">316</PROPERTY>
  </HEADER>
EOF
}

sub endmatter {
    print '  <LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="utterance" TIME_ALIGNABLE="true" GRAPHIC_REFERENCES="false"/>', "\n";
    print '  <LOCALE LANGUAGE_CODE="en" COUNTRY_CODE="US"/>', "\n";
    print "</ANNOTATION_DOCUMENT>\n";
}
