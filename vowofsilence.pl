use warnings;
use strict;
use LWP::UserAgent;
use URI;

use vars qw($VERSION %IRSSI);
%IRSSI = (
	authors		=> "Kafan",
	contact		=> 'github.com/tsumare',
	name		=> "vowofsilence",
	description => "Keeps you from speaking in certain channels",
	license		=> "GPLv3",
);

sub should_trigger ($$) {
	my ($server, $target) = @_;
	my @TriggerFor = split /\s+/, Irssi::settings_get_str('vowofsilence_targets');
	return 0 unless (@TriggerFor);
	foreach my $Trigger (@TriggerFor) {
		return 1 if (lc($Trigger) eq lc($server->{tag}."/".$target));
		return 1 if (lc($Trigger) eq lc($server->{tag}."/"));
		return 1 if (lc($Trigger) eq lc($target));
	}
	return 0;
}

sub sig_send_text ($$$) {
	my ($line, $server, $witem) = @_;
	return unless (ref $server);
	return unless ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'));
	return unless should_trigger($server, $witem->{name});
	Irssi::signal_stop();
	my $target = $witem->{name};
	Irssi::active_win()->command("echo Message to $target intercepted."); 
	Irssi::active_win()->command("echo To bypass, /msg $target $line"); 
}

sub sig_own_action ($$$) {
	my ($server, $msg, $target) = @_;
	return unless (ref $server);
	return unless should_trigger($server, $target);
	Irssi::signal_stop();
	Irssi::active_win()->command("echo Message to $target intercepted."); 
	Irssi::active_win()->command("echo To bypass, /msg $target $msg"); 
}

Irssi::settings_add_str($IRSSI{name}, 'vowofsilence_targets', '');
Irssi::signal_add_first('send text', 'sig_send_text');
Irssi::signal_add_first('message irc own_action', 'sig_own_action'); # SERVER_REC, char *msg, char *target
Irssi::signal_add_first('message irc own_notice', 'sig_own_action'); # SERVER_REC, char *msg, char *target

# vim: set ft=perl ts=4 sw=4 sts=4 nosta noet ai : 
