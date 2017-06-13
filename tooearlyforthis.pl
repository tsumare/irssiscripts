use warnings;
use strict;
use LWP::UserAgent;
use URI;
use POSIX;

use vars qw($VERSION %IRSSI);
%IRSSI = (
	authors		=> "Kafan",
	contact		=> 'github.com/tsumare',
	name		=> "tooearlyforthis",
	description => "Keeps you from speaking in certain channels first thing in the morning",
	license		=> "GPLv3",
);

sub should_trigger ($$) {
	my ($server, $target) = @_;
	my @TriggerFor = split /\s+/, Irssi::settings_get_str('tooearlyforthis_targets');
	return 0 unless (@TriggerFor);
	foreach my $Trigger (@TriggerFor) {
		my $RetVal = 1;
		if (substr($Trigger,0,1) eq '!') {
			$RetVal = 0;
			$Trigger = substr($Trigger,1);
		}
		return $RetVal if (lc($Trigger) eq lc($server->{tag}."/".$target));
		return $RetVal if (lc($Trigger) eq lc($server->{tag}."/"));
		return $RetVal if (lc($Trigger) eq lc($target));
	}
	return 0;
}

sub time_remaining_check () {
	my $TimeFile = Irssi::settings_get_str('tooearlyforthis_timefile');
	my $FirstHour = Irssi::settings_get_int('tooearlyforthis_newdayfirsthour');
	my $DelaySeconds = Irssi::settings_get_int('tooearlyforthis_delayseconds');
	my $FileDay;
	my $SpeakAfter;
	my $CurrentDay = int(POSIX::strftime("%Y%m%d", localtime()));
	my $Now = time();
	{
		if (open(my $rfd, '<'.$TimeFile)) {
			my $l = <$rfd>;
			chomp $l;
			close($rfd);
			($FileDay, $SpeakAfter) = map { int($_) } split / /, $l;
		}
		else {
			$FileDay = 0;
			$SpeakAfter = 0;
		}
	}
	my @localtime = localtime();
	if ($localtime[2] < $FirstHour) {
		$CurrentDay--; # It's not today yet.
	}
	if ($FileDay != $CurrentDay) {
		$SpeakAfter = time()+$DelaySeconds;
		open(my $wfd, '>'.$TimeFile);
		printf $wfd "%d %d\n", $CurrentDay, $SpeakAfter;
		close($wfd);
	}
	return 0 if ($Now > $SpeakAfter);
	return int($SpeakAfter - $Now);
}

sub sig_send_text ($$$) {
	my ($line, $server, $witem) = @_;
	return unless (ref $server);
	return unless ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'));
	return unless should_trigger($server, $witem->{name});
	my $TimeLeft = time_remaining_check();
	return unless ($TimeLeft > 0);
	Irssi::signal_stop();
	my $target = $witem->{name};
	Irssi::active_win()->command(sprintf("echo Message to $target intercepted.  Please spend another %.2f minutes waking up.", $TimeLeft/60));
	#Irssi::active_win()->command("echo To bypass, /msg $target $line"); 
}

sub sig_own_action ($$$) {
	my ($server, $msg, $target) = @_;
	return unless (ref $server);
	return unless should_trigger($server, $target);
	my $TimeLeft = time_remaining_check();
	return unless ($TimeLeft > 0);
	Irssi::signal_stop();
	Irssi::active_win()->command(sprintf("echo Message to $target intercepted.  Please spend another %.2f minutes waking up.", $TimeLeft/60));
	#Irssi::active_win()->command("echo To bypass, /msg $target $msg"); 
}

Irssi::settings_add_str($IRSSI{name}, 'tooearlyforthis_targets', '');
Irssi::settings_add_str($IRSSI{name}, 'tooearlyforthis_timefile', $ENV{HOME}.'/.tooearlyforthis.time');
Irssi::settings_add_int($IRSSI{name}, 'tooearlyforthis_newdayfirsthour', 4);
Irssi::settings_add_int($IRSSI{name}, 'tooearlyforthis_delayseconds', 3600);
Irssi::signal_add_first('send text', 'sig_send_text');
Irssi::signal_add_first('message irc own_action', 'sig_own_action'); # SERVER_REC, char *msg, char *target
Irssi::signal_add_first('message irc own_notice', 'sig_own_action'); # SERVER_REC, char *msg, char *target

# vim: set ft=perl ts=4 sw=4 sts=4 nosta noet ai : 
