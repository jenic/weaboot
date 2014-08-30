#!/usr/bin/perl -w

# Modified from the original example as detailed below:
#
# $Id: dcctest.pl,v 3.5 2005/02/19 13:26:46 chris Exp $
#
# This simple test program should give you an idea of how a basic
# POE::Component::IRC script fits together.
# -- dennis taylor, <dennis@funkplanet.com>

use strict;
use lib $ENV{HOME} . '/lib/perl/';
use POE::Kernel;
use POE::Session;
use POE::Component::IRC;

my $nick = "rycr" . ($$ % 1000);

sub _stop;
sub irc_notice;
sub irc_msg;

END { $poe_kernel->call('test', 'quit', 'thanks!') }

# Expected args format:
# <>    <0>         <1>     <2>
# <cmd> <packid>    <bot>   <channel> [ <server> ] [ <port> ]

my @pack = split ',', $ARGV[0] || undef;
my $bot = $ARGV[1] || 'CR-CA|NEW';
my $chan = $ARGV[2] || '#horriblesubs';
my $i = 0;

die "NEED PACK NUMBER!" unless @pack;
print "Fetching packs @pack from $bot in $chan\n";

# This gets executed as soon as the kernel sets up this session.
sub _start {
    my ($kernel, $session) = @_[KERNEL, SESSION];

    # Ask the IRC component to send us all IRC events it receives. This
    # is the easy, indiscriminate way to do it.
    $kernel->post( 'test', 'register', 'all');

    # Setting Debug to 1 causes P::C::IRC to print all raw lines of text
    # sent to and received from the IRC server. Very useful for debugging.
    $kernel->post( 'test', 'connect',
                { Debug    => 0
                , Nick     => $nick,
                , Server   => $ARGV[3] || 'irc.rizon.net',
                , Port     => $ARGV[4] || 6667,
                , Username => 'rycr',
                , Ircname  => 'iambestgirl'
                }
    );
}


# After we successfully log into the IRC server, join a channel.
sub irc_001 {
    my ($kernel) = $_[KERNEL];
    my $sender = $_[SENDER];
    my $irc = $sender->get_heap();

    print "Connected to ", $irc->server_name(), "\n";

    $kernel->post( 'test', 'mode', $nick, '+i' );
    $kernel->post( 'test', 'join', $chan );
    print "Asking $bot for @pack\n";
    $kernel->post( 'test', 'privmsg', $bot, "xdcc send $_" ) for (@pack);

    return;
}

sub irc_dcc_done {
    my ($magic, $nick, $type, $port, $file, $size, $done) = @_[ARG0 .. ARG6];
    print "DCC $type to $nick ($file) done: $done bytes transferred.\n";
    # TODO: Close session
    $i++;
    exit if ($i == @pack);
}


sub irc_dcc_error {
    my ($err, $nick, $type, $file) = @_[ARG0 .. ARG2, ARG4];
    print "DCC $type to $nick ($file) failed: $err.\n",
}


sub _stop {
    my ($kernel) = $_[KERNEL];

    print "Control session stopped.\n";
    $kernel->call( 'test', 'quit', 'thanks!' );
}


sub irc_disconnected {
    my ($server) = $_[ARG0];
    print "Lost connection to server $server.\n";
}

sub irc_msg {
    my ($kernel, $who, $chan, $msg) = @_[KERNEL, ARG0 .. ARG2];
    print "MSG from $who: $msg\n";
}

sub irc_notice {
    my ($kernel, $who, $chan, $msg) = @_[KERNEL, ARG0 .. ARG2];
    print "NOTICE from $who: $msg\n";
}

sub irc_error {
    my $err = $_[ARG0];
    print "Server error occurred! $err\n";
}

sub irc_socketerr {
    my $err = $_[ARG0];
    print "Couldn't connect to server: $err\n";
}

sub irc_kick {
    my ($who, $where, $isitme, $reason) = @_[ARG0 .. ARG4];

    print "Kicked from $where by $who: $reason\n" if $isitme eq $nick;
}

sub irc_dcc_request {
    my ($kernel, $nick, $type, $port, $magic, $filename, $size) =
    @_[KERNEL, ARG0 .. ARG5];

    print "DCC $type request from $nick on port $port\n";
    $nick = ($nick =~ /^([^!]+)/);
    $nick =~ s/\W//;
    $kernel->post( 'test', 'dcc_accept', $magic, "$1.$filename" );
}


# here's where execution starts.

my $irc = POE::Component::IRC->spawn(
    alias=>'test'
) or die "Can't instantiate new IRC component: $!\n";

POE::Session->create( package_states => [ 'main' => [
            qw(_start _stop irc_001 irc_kick irc_disconnected irc_error
            irc_notice irc_socketerr irc_dcc_done irc_dcc_error
            irc_dcc_request irc_msg)
            ],
        ],
        heap => { irc => $irc },
);
$poe_kernel->run();

exit 0;
