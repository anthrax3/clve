#!/usr/bin/env perl

use strict;
use warnings;

use Time::Piece;

my ($file) = @ARGV;
die 'usage: <scenario>' unless $file && -f $file;

open my $fh, '<', $file or die $!;
my @actions = grep { !/^#/ && $_ } map { chomp $_; $_ } <$fh>;
close $fh;

my @TRACKS;

my $i = 0;
foreach my $action (@actions) {
    my ($type, $params) = split /\s+/, $action, 2;

    my @params;
    while ($params =~ m{\s*(?:([^'" ]+)|"(.*?)"|'(.*?)')}gc) {
        push @params, $1 || $2 || $3;
    }

    no strict 'refs';
    my $cb = "_action_$type";
    my $cmd = $cb->(@params);

    my $output = sprintf 'output-%04d.mp4', $i++;
    $cmd = "$cmd $output";

    print "$cmd\n";
    `$cmd`;
}

#my $cmd = 'melt -progress ';
#foreach my $track (@TRACKS) {
#    $cmd .= $track . ' ';
#}
#$cmd .= " -consumer avformat:output.mp4 acodec=libmp3lame vcodec=libx264 frame_rate=60 width=1280 height=720";
#
#print "$cmd\n";
##`$cmd`;

unlink $_ for glob '.clve-tmp*png';

sub _action_crop {
    my ($file, $from, $to) = @_;

    $from = _normalize_time($from);
    $to   = _normalize_time($to);

    my $t = _to_seconds($to) - _to_seconds($from);

    return qq{ffmpeg -i $file -ss $from -t $t -c:a copy -c:v libx264 -crf 18 -preset veryfast };
}

#sub _action_cat {
#    my ($file) = @_;
#
#    push @TRACKS, "$file";
#}

sub _action_text {
    my ($text) = @_;

    my $file = _temp_name('.clve-tmp-text-');

    my $cmd =
        qq{convert -background black -fill white }
      . qq{ -colorspace RGB -depth 32 }
      #. qq{ -font 'Droid-Serif-Regular' -pointsize 80 }
      . qq{ -pointsize 80 }
      . qq{ -size 1280x720 -gravity Center caption:'$text' }
      . qq{ 'PNG32:$file.png'};

    print "$cmd\n";
    `$cmd`;

    my $length = int(length($text) / 30 + 2) * 60;

    return qq{ffmpeg -framerate 60 -loop 1 -i $file.png -c:v libx264 -pix_fmt yuv420p -t 2 };
}

sub _action_img {
    my ($image) = @_;

    my $file = _temp_name('.clve-tmp-img-');

    my $cmd =
        qq{convert $image}
      . q{ -thumbnail 1280x720}
      . q{ -background black}
      . q{ -gravity center}
      . q{ -extent 1280x720}
      . qq{ 'PNG32:$file.png'};

    print "$cmd\n";
    `$cmd`;

    return qq{ffmpeg -framerate 60 -loop 1 -i $file.png -c:v libx264 -pix_fmt yuv420p -t 2 };
}

sub _normalize_time {
    my ($time) = @_;

    my ($sec, $min, $hour) = reverse split /:/, $time;
    $sec  ||= 0;
    $min  ||= 0;
    $hour ||= 0;

    return sprintf('%02d:%02d:%02d', $hour, $min, $sec);
}

sub _to_seconds {
    my ($time) = @_;

    my ($hour, $min, $sec) = split /:/, $time;

    return $hour * 3600 + $min * 60 + $sec;
}

sub _temp_name {
    my ($prefix) = @_;

    my $file = $prefix;
    $file .= int(rand(10)) for 1 .. 16;

    return $file;
}

