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
use POE qw(Component::IRC);
use Getopt::Long;
use Pod::Usage;

sub _stop;
sub irc_notice;
sub irc_msg;

END { $poe_kernel->call('test', 'quit', 'thanks!') }

# Expected args format:
# <>    <0>         <1>     <2>
# <cmd> <packid>    <bot>   <channel> [ <server> ] [ <port> ]

my @pack;
my $bot = $ENV{BOT} || 'CR-TEXAS|NEW';
my $chan = '#horriblesubs';
my $limit = 2;
my $nick = "rycr" . ($$ % 1000);
my $server = 'irc.rizon.net';
my $port = 6667;

my $i = 0;
my ($xdcc_send, $help, $man);

GetOptions
( 'packs=s{1,}' => \@pack
, 'bot=s' => \$bot
, 'channel=s' => \$chan
, 'limit=i' => \$limit
, 'nickname=s' => \$nick
, 'server=s' => \$server
, 'port=i' => \$port
, 'help|?' => \$help
, man => \$man
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

die "NEED PACK NUMBER!" unless @pack;
print "Fetching @pack from $bot in $chan on $server:$port (Limit $limit)\n";

# Helper for sending requests
sub xdcc {
    my $irc = shift;
    my @stack = (@_);

    return sub {
        my $bot = shift;
        my @slice = splice @stack, 0, $limit;
        return unless @slice;
        print "Asking $bot for @slice\n";
        print @stack . " left in stack\n";
        $irc->yield( privmsg => $bot => "xdcc send $_" )
            for (@slice);
    };
}

# This gets executed as soon as the kernel sets up this session.
sub _start {
    my $heap = $_[HEAP];
    my $irc = $heap->{irc};
    $xdcc_send = xdcc($irc, @pack);

    # Ask the IRC component to send us all IRC events it receives. This
    # is the easy, indiscriminate way to do it.
    $irc->yield( register => 'all' );
    $irc->yield( 'connect' );

    return;
}


# 001 means we have successfully passed connection and registration phase
sub irc_001 {
    my $sender = $_[SENDER];
    my $irc = $sender->get_heap();

    print "Connected to ", $irc->server_name(), "\n";

    $irc->yield( mode => $nick => '+i' );
    $irc->yield( join => $chan );
    $xdcc_send->($bot);

    return;
}

sub irc_dcc_done {
    my ($magic, $nick, $type, $port, $file, $size, $done) = @_[ARG0 .. ARG6];
    print "DCC $type to $nick ($file) done: $done bytes transferred.\n";
    # TODO: Close session
    $i++;
    exit if ($i == @pack);
    $xdcc_send->($bot);
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
    my ($server, $heap) = @_[ARG0, HEAP];
    my $irc = $heap->{irc};
    print "Lost connection to server $server.\n";

    $irc->yield(connect=>{});
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
    $nick = ($nick =~ /^([^!]+)/)[0];
    if (lc($nick) ne lc($bot)) {
        print "Request not expected. Expected request from $bot, got $nick\n";
        return;
    }

    $kernel->post( 'test', 'dcc_accept', $magic, "$1.$filename" );
}


# here's where execution starts.

my $irc = POE::Component::IRC->spawn(
    debug=> $ENV{DEBUG} || 0,
    options=> { trace => $ENV{TRACE} || 0 },
    plugin_debug=>0,
    alias=>'test',
    nick=>$nick,
    server=>$server,
    port=>$port,
    username=>$nick,
    ircname=>'ircpls'
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

__END__

=head1 weaboot

Weaboo XDCC Leech Bot

=head1 SYNOPSIS

weaboot --packs 1 [2 3 ...] [ --nick bob ] [ --limit <number> ] [ --bot <name> ] [ --channel <name> ]

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exit

=item B<-man>

Prints the manual page and exits

=item B<-nick>

The IRC nickname to use
Default: rycr<PID %% 1000>

=item B<-limit>

The integer limit for how many packs to request at one time
Default: 2

=item B<-bot>

The name of the bot to request packs from. Default: CR-TEXAS|NEW

=item B<-channel>

The channel to join before requesting packs from the bot. This is typically
because bots will check that you are in a channel they are in before accepting
XDCC requests.
Default: #horriblesubs

=item B<-packs>

List of packs to request expressed as space separated values.
Required argument.
Example: weaboot --packs 321 231 123

=item B<-server>

IRC server to connect to
Default: irc.rizon.net

=item B<-port>

Port to connect to irc server on
Default: 6667

=back

=head1 DESCRIPTION

B<weaboot> will connect to the given irc network to request XDCC packs from a
bot within a channel. This is to facilitate mass downloads when packlist
support is not functional. (Which is all the time)

=cut
