#!/usr/bin/perl

# lari.lampen@mpi.nl, 2010

use strict;

# --- Read input ---
if ($#ARGV < 0) {
    die "Usage: perl lrc2eaf lrcfile [mediafile]";
}
my $infile=$ARGV[0];
open IF,$infile || die "Failed to open file";
my @lines=<IF>;
chomp @lines;
close IF;

my $prefix=$infile;
$prefix =~ s/\.[^\.]*$//;
my $vid_url="file://$prefix.mp3";
if ($#ARGV>0) {
    $vid_url = "file://" . $ARGV[1];
}
my $outfile=$prefix.".eaf";
my ($artist, $title);

my @contents;
my @ids;
my $counter = 1;

my %items;

# --- Start file (print header) ---
open OF, ">$outfile";
preamble();

# --- Collect contents, convert times to ms ---
foreach my $line (@lines) {
    $line =~ /\[(.*)\](.*)/;
    my $times = $1;
    my $content = $2;

    if ($times =~ /ti:(.*)/) {
	$title = $1;
	next;
    } elsif ($times =~ /ar:(.*)/) {
	$artist = $1;
	next;
    } elsif ($content eq "") {
	next;
    }

    my @times=split(/[\[\]]+/,$times);
    foreach my $time (@times) {
	my $ms = mmssxx2ms($time);
	$items{$ms}=$content;
    }
}

# --- Print list of time slots ---
print OF "  <TIME_ORDER>\n";
my @keys=sort {$a <=> $b} keys %items;
for (my $i=0; $i<=$#keys; $i++) {
    my $time=$keys[$i];
    my $content=$items{$time};

    print_timeslot($time);
    my $end=0;
    if ($i<$#keys) {
	$end = $keys[$i+1]-100;
    } else {
	$end = $time+5000;
    }
    print_timeslot($end);
    push @contents, $content;
}
print OF "  </TIME_ORDER>\n";



# --- Print list of annotations ---
print OF "  <TIER TIER_ID=\"lyrics\" LINGUISTIC_TYPE_REF=\"utterance\" DEFAULT_LOCALE=\"en\">\n";
$counter=1;
while ($#contents>=0) {
    my $content=shift(@contents);
    my $id="a$counter";
    my $start=shift(@ids);
    my $end=shift(@ids);

    print OF "    <ANNOTATION>\n";
    print OF "      <ALIGNABLE_ANNOTATION ANNOTATION_ID=\"$id\" TIME_SLOT_REF1=\"$start\" TIME_SLOT_REF2=\"$end\">\n";
    print OF "        <ANNOTATION_VALUE>$content</ANNOTATION_VALUE>\n";
    print OF "      </ALIGNABLE_ANNOTATION>\n";
    print OF "    </ANNOTATION>\n";
    $counter++;
}
print OF "  </TIER>\n";

# --- End file ---
endmatter();
close OF;



# Convert "mm:ss:xx" to milliseconds. 
sub mmssxx2ms {
    my $t=shift;
    my @fields=split(/[:\.]/,$t);
    
    return 10*strip0($fields[2])
        +1000*strip0($fields[1])
        +60*1000*strip0($fields[0]);
}
    
sub strip0 {
    my ($in)=@_;
    $in =~ s/^0+//;
    return $in;
}

# Print time slot and store the time slot id in @ids.
sub print_timeslot {
    my ($time)=@_;
    my $id="ts$counter";

    print OF "    <TIME_SLOT TIME_SLOT_ID=\"$id\" TIME_VALUE=\"",
          int($time), "\"/>\n";
    push @ids, $id;
    $counter++;
}

sub preamble {
    print OF <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<ANNOTATION_DOCUMENT xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.mpi.nl/tools/elan/EAFv2.5.xsd" DATE="2008-03-19T16:07:44+00:00" AUTHOR="" VERSION="2.5" FORMAT="2.5">
  <HEADER MEDIA_FILE="" TIME_UNITS="milliseconds">
    <MEDIA_DESCRIPTOR MEDIA_URL="$vid_url" MIME_TYPE="audio/mp3" RELATIVE_MEDIA_URL="$vid_url"/>
    <PROPERTY NAME="lastUsedAnnotationId">316</PROPERTY>
  </HEADER>
EOF
}

sub endmatter {
    print OF '  <LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="utterance" TIME_ALIGNABLE="true" GRAPHIC_REFERENCES="false"/>', "\n";
    print OF '  <LOCALE LANGUAGE_CODE="en" COUNTRY_CODE="US"/>', "\n";
    print OF "</ANNOTATION_DOCUMENT>\n";
}

