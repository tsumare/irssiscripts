use warnings;
use strict;
use LWP::UserAgent;
use URI;

use vars qw($VERSION %IRSSI);
%IRSSI = (
	authors		=> "Kafan Tsumare",
	contact		=> 'github.com/tsumare',
	name		=> "bitly",
	description => "Automatically uses bit.ly to shorten any links sent to a given set of targets.",
	license		=> "GPLv3",
);

our %bitlycache;

sub bitlyify ($) {
	my ($line) = @_;
	local %bitlycache = ();
	$line =~ s!(ht|f)tps?://((([^ :@]+:[^ :@]+@)?([a-z0-9_-]{1,63}\.)+[a-z]{2,5})|(([0-9]{1,3}\.){3}[0-9]{1,3}))/?([^ /\?]+/)*[^ /\?]*(\\?[^ ]*)?!shorten($&)!egi;
	return $line;
}

sub shorten ($) {
	my $longUrl = shift;
	return $longUrl if ($longUrl =~ m!^http://bit\.ly/!);
	return $longUrl unless (Irssi::settings_get_str('bitly_username'));
	return $longUrl unless (Irssi::settings_get_str('bitly_apikey'));

	my $lwp = LWP::UserAgent->new;
	$lwp->agent("irssi");

	my $url = URI->new('http://api.bit.ly/v3/shorten');
	$url->query_form(
		format => 'txt',
		login => Irssi::settings_get_str('bitly_username'),
		apiKey => Irssi::settings_get_str('bitly_apikey'),
		longUrl => $longUrl
	);

	my $response = $lwp->get($url->as_string);

	if ($response->is_success) {
		my $data = $response->decoded_content();
		chomp $data;
		if ($data eq 'http://bit.ly/undefined') {
			print CLIENTERROR "We have been ratelimited." 
		}
		else {
			return $data;
		}
	}
	else {
		print CLIENTERROR "An error occurred while making the HTTP Request for $url\n";
	}
	return $longUrl;
}

sub should_trigger ($$) {
	my ($server, $witem) = @_;
	my @TriggerFor = split /\s+/, Irssi::settings_get_str('bitly_targets');
	return 1 unless (@TriggerFor);
	foreach my $Trigger (@TriggerFor) {
		return 1 if (lc($Trigger) eq lc($server->{tag}."/".$witem->{name}));
		return 1 if (lc($Trigger) eq lc($server->{tag}."/"));
		return 1 if (lc($Trigger) eq lc($witem->{name}));
	}
	return 0;
}

sub sig_send_text ($$$) {
	my ($line, $server, $witem) = @_;
	return unless (ref $server);
	return unless ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'));
	return unless should_trigger($server, $witem);
	Irssi::signal_continue(bitlyify($line), $server, $witem);
}
Irssi::settings_add_str($IRSSI{name}, 'bitly_targets', '');
Irssi::settings_add_str($IRSSI{name}, 'bitly_username', '');
Irssi::settings_add_str($IRSSI{name}, 'bitly_apikey', '');
Irssi::signal_add_first('send text', 'sig_send_text');

# vim: set ft=perl ts=4 sw=4 sts=4 nosta noet ai : 
