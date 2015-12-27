use warnings;
use strict;

#use POSIX;
use Date::Format;
use Data::Dumper;

use vars qw($VERSION %IRSSI);
%IRSSI = (
	authors		=> "Kafan Tsumare",
	contact		=> 'github.com/tsumare',
	name		=> "pastebin_fetcher",
	description => "Automatically saves pastebin posts in given channels to a particular directory.",
	license		=> "GPLv3",
);

my %Dedup;

sub should_trigger ($$) {
	my ($servertag, $targetname) = @_;
	my @TriggerFor = split /\s+/, Irssi::settings_get_str('pastebin_targets');
	return 1 unless (@TriggerFor);
	foreach my $Trigger (@TriggerFor) {
		return 1 if (lc($Trigger) eq lc($servertag."/".$targetname));
		return 1 if (lc($Trigger) eq lc($servertag."/"));
		return 1 if (lc($Trigger) eq lc($targetname));
	}
	return 0;
}

sub paste_scan_self {
	my ($server, $data, $target, $orig_target) = @_;
	# "message own_public", SERVER_REC, char *msg, char *target
	# "message own_private", SERVER_REC, char *msg, char *target, char *orig_target
	paste_scan($server, $data, $server->{nick}, $server->{userhost}, $target);
}

sub paste_scan {
	my ($server, $data, $nick, $mask, $target) = @_;
	return unless (should_trigger($server->{tag}, (defined($target) ? $target : $nick)));

	my %Pastes;
	for my $id ($data =~ /pastebin\.com\/(?:raw\.php\?i=)?([A-Za-z0-9]{8,10})\b/g) {
		$Pastes{"pastebin_".$id} = { url => 'http://pastebin.com/raw.php?i='.$id };
	}
	for my $id ($data =~ /dpaste\.com\/([A-Za-z0-9]+)\//g) {
		$Pastes{"dpaste_".$id} = { url => 'http://dpaste.com/'.$id.'.txt' };
	}
	for my $id ($data =~ /bpaste\.net\/(?:raw|show)\/([0-9]+)\//g) {
		$Pastes{"bpaste_".$id} = { url => 'http://bpaste.net/raw/'.$id.'/' };
	}
	for my $id ($data =~ /sprunge\.us\/([A-Za-z0-9]+)/g) {
		$Pastes{"sprunge_".$id} = { url => 'http://sprunge.us/'.$id };
	}
	for my $id ($data =~ /pastebin.ca\/(?:raw\/)?([0-9]+)/g) {
		$Pastes{"pastebinca_".$id} = { url => 'http://pastebin.ca/raw/'.$id };
	}

	my @Time = localtime(time());
	my $Timebase = strftime(Irssi::settings_get_str('pastebin_outdir'), @Time);
	my $ftag = $server->{tag};
	my $ftarget = (defined($target) ? $target : $nick);

	my $lftag = lc($ftag);
	my $lnick = lc($nick);
	my $lftarget = lc($ftarget);

	for my $d (keys %Dedup) {
		delete $Dedup{$d} if ($Dedup{$d} < time() - Irssi::settings_get_int('pastebin_deduplicate_window'));
	}

	for my $id (keys %Pastes) {
		my $ddk = Irssi::settings_get_str('pastebin_deduplicate_key');
		$ddk =~ s/\$lT/$lftag/g;
		$ddk =~ s/\$ln/$lnick/g;
		$ddk =~ s/\$lt/$lftarget/g;
		$ddk =~ s/\$f/$id/g;
		$ddk =~ s/\$T/$ftag/g;
		$ddk =~ s/\$n/$nick/g;
		$ddk =~ s/\$t/$ftarget/g;
		if (exists($Dedup{$ddk})) {
			delete $Pastes{$id};
			next;
		}
		$Dedup{$ddk} = time();

		# Generate Directory & Filename
		$Pastes{$id}->{file} = $Timebase;
		$Pastes{$id}->{file} =~ s/\$lT/$lftag/g;
		$Pastes{$id}->{file} =~ s/\$ln/$lnick/g;
		$Pastes{$id}->{file} =~ s/\$lt/$lftarget/g;
		$Pastes{$id}->{file} =~ s/\$f/$id/g;
		$Pastes{$id}->{file} =~ s/\$T/$ftag/g;
		$Pastes{$id}->{file} =~ s/\$n/$nick/g;
		$Pastes{$id}->{file} =~ s/\$t/$ftarget/g;

		my @mkdir = split /\//, $Pastes{$id}->{file};
		pop @mkdir; # filename
		for (my $i = 0; $i < scalar @mkdir; $i++) {
			my $Dir = join("/", @mkdir[0..$i]);
			mkdir($Dir) unless (-e $Dir);
		}
	}

	my $pid = fork();
	unless (defined($pid)) {
		Irssi::print("Can't fork - aborting pastebin fetch");
		return;
	}
	if ($pid > 0) {
		# the original process
		Irssi::pidwait_add($pid);
	} else {
		# the new process
		for my $id (keys %Pastes) {
			system('wget', '-qO', $Pastes{$id}->{file}, $Pastes{$id}->{url});
		}
		POSIX::_exit(1);
	}
}

Irssi::settings_add_int($IRSSI{name}, 'pastebin_deduplicate_window', 86400);
Irssi::settings_add_str($IRSSI{name}, 'pastebin_deduplicate_key', '$T $lt $ln $f');
Irssi::settings_add_str($IRSSI{name}, 'pastebin_targets', '');
Irssi::settings_add_str($IRSSI{name}, 'pastebin_outdir', $ENV{HOME}.'/pastebin/$T/$lt/%Y-%m-%d %H:%M:%S $n $f.txt'); # $f id; $T ($lT) tag; $t ($lt) target; $n ($ln) nick; %x dateformat
Irssi::signal_add_last('message public', \&paste_scan);
Irssi::signal_add_last('message private', \&paste_scan);
Irssi::signal_add_last('message irc action', \&paste_scan);
Irssi::signal_add_last('message own_public', \&paste_scan_self);
Irssi::signal_add_last('message own_private', \&paste_scan_self);
Irssi::signal_add_last('message irc own_action', \&paste_scan_self);
