#!/usr/bin/perl

use warnings;
use strict;
use Prima qw(Application MsgBox);

my $url = shift;
die "Usage: $0 URL\n" if ! $url;

my $cfg;
$cfg->{comment_char} = '#';
$cfg->{fileName} = "$ENV{HOMEDRIVE}/etc/sessions.ini";
# $cfg->{fileName} = "E:/win/etc/sessions.ini";

sub ok
{
    die "Aieee! You clicked 'OK'!\n";
}

sub bork_with ($) {
    my $error = shift;
    message("ERROR: $error", mb::Ok|mb::Error, 
        buttons => {
            mb::Ok => {
                # text    => 'OK',
            },
        }
    );
}

sub DEBUG { 1 }
sub Print ($) {
    DEBUG && print shift;
}

sub read_config
{
    my $ini = $cfg->{fileName};
    my $ok;

    my $sect = '*** GLOBAL CONFIG ***';
    my $parm;

    # Print "Reading '$ini'\n";
    open (my $ini_fh, "$ini") || die "Can't read '$ini': $!\n";
    while (defined (my $line = <$ini_fh>)) {

        next if $line =~ /^$cfg->{comment_char}/;

        if ( $line =~ /^\[([^]]+)\]\s+$/ ) {
            $sect = $1;
            $cfg->{sects}->{$sect} = undef;
        }
        elsif ( $line =~ /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ ) {
            $parm = $1;
            $cfg->{data}->{$sect}->{$parm} = $2;
        }

    }
    # close $ini_fh;
    CORE::close $ini_fh;

}

read_config();

sub launch_putty ($)
{

    my $host = shift;

    my $user_at_host;

    if ( $host =~ /@/ ) {
        $user_at_host = $host;
    } else {
        $user_at_host = $cfg->{data}->{settings}->{user} .
        '@'.
        $host;
    }

    my @args = (
        $cfg->{data}->{settings}->{putty}, "-ssh", $user_at_host
    );

    print join " ", @args, $/;

    my $msg = "";
    system(1,@args);
    if ($? == -1) {
        $msg = sprintf "Failed to execute: $!\n";
    }
    Prima::MsgBox::message($msg) if $msg;

}

if ( $url =~ m{^ssh://(.*)$} ) {
    launch_putty($1);
} else {
    bork_with("Got '$url' for a URL?");
}

