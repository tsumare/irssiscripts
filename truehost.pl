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
	name        => 'FixHosts',
	description => 'Fix hosts.',
	license     => 'GNU GPLv3',
);

sub do_host {
	my $server = shift;
	return unless $server;
	my $IP = get_ip();
	return unless $IP;
	my $DNS = get_host($IP);
	$DNS = $IP unless $DNS;
	$server->send_raw(sprintf('WEBIRC %s cgiirc %s %s', Irssi::settings_get_str('webirc_key'), $DNS, $IP));
}

sub get_ip {
	open(LAST, '-|', '/usr/bin/last', '-ai', $ENV{USER});
	while (<LAST>) {
		last if /^$/;
		my @Entry = split /\s+/, $_;
		$_ = pop @Entry;
		next if /^127\./;
		next if /^10\./;
		next if /^192\.168\./;
		next if /^172\.(1[6-9]|2[0-9]|3[0-1])\./;
		return $_;
	}
	return undef;
}

sub get_host {
	return gethostbyaddr(inet_aton(shift), AF_INET);
}

Irssi::settings_add_str($IRSSI{name}, 'webirc_key', '');
Irssi::signal_add_first("server connected", "do_host");
