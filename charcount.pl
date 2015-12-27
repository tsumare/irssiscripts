use warnings;
use strict;

use Irssi::TextUI; # http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=281097

use vars qw($VERSION %IRSSI);
%IRSSI = (
	authors		=> "Kafan Tsumare",
	contact		=> "github.com/tsumare",
	name		=> "bitly",
	description => "Automatically uses bit.ly to shorten any links sent to a given set of targets.",
	license		=> "GPLv2",
);

sub should_trigger ($$) {
	my ($server, $witem) = @_;
	my @TriggerFor = split /\s+/, Irssi::settings_get_str('charcount_targets');
	return 1 unless (@TriggerFor);
	foreach my $Trigger (@TriggerFor) {
		return 1 if (lc($Trigger) eq lc($server->{tag}."/".$witem->{name}));
		return 1 if (lc($Trigger) eq lc($server->{tag}."/"));
		return 1 if (lc($Trigger) eq lc($witem->{name}));
	}
	return 0;
}

sub sbupdate {
	my ($statusitem, $get_size_only) = @_;
	my $win = Irssi::active_win();
	unless (ref($win) && ref($win->{active_server}) && ref($win->{active}) && should_trigger($win->{active_server},$win->{active})) {
		$statusitem->default_handler($get_size_only, '{}', '', 1);
	}
	else {
		my $charcount = Irssi::parse_special('$@L');
		my $warnchars = Irssi::settings_get_int('charcount_warnchars');
		my $alertchars = Irssi::settings_get_int('charcount_alertchars');
		my $colorcode = '';
		$colorcode = Irssi::settings_get_str('charcount_warncolor') if ($warnchars > 0 && $charcount >= $warnchars);
		$colorcode = Irssi::settings_get_str('charcount_alertcolor') if ($alertchars > 0 && $charcount >= $alertchars);
		$statusitem->default_handler($get_size_only, $colorcode.'{sb $0-}', $charcount, 1);
	}
}
Irssi::settings_add_str($IRSSI{name}, 'charcount_targets', '');
Irssi::settings_add_int($IRSSI{name}, 'charcount_warnchars', 0);
Irssi::settings_add_str($IRSSI{name}, 'charcount_warncolor', '%Y');
Irssi::settings_add_int($IRSSI{name}, 'charcount_alertchars', 0);
Irssi::settings_add_str($IRSSI{name}, 'charcount_alertcolor', '%R');
Irssi::statusbar_item_register('charcount', 0, 'sbupdate');
Irssi::signal_add_last 'gui key pressed' => sub { Irssi::statusbar_items_redraw('charcount'); };
