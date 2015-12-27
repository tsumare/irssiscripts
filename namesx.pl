use strict;
use warnings;
use Irssi;
use Irssi::Irc;
use Socket;
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.1";
%IRSSI = (
	authors     => 'Kafan Tsumare',
	contact     => 'github.com/tsumare',
	name        => 'NAMESX',
	description => 'Announce that we support NAMESX.',
	license     => 'GPLv3',
);

sub do_protoctl {
	my $server = shift;
	$server->send_raw('PROTOCTL NAMESX');
}

Irssi::signal_add_first("server connected", "do_protoctl");
