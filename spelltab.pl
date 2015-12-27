use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(signal_add_last settings_add_int settings_get_int);
use Text::Aspell qw();

$VERSION = '1.00';
%IRSSI = (
	authors     => 'Kafan Tsumare',
	contact     => 'github.com/tsumare',
	name        => 'Aspell Tabcomplete',
	description => 'Adds any Aspell suggestions to the tabcomplete list.',
	license     => 'GPLv3',
);

sub docomplete {
	my ($complist, $window, $word, $linestart, $want_space) = @_;

	my $Speller = Text::Aspell->new();
	$Speller->create_speller() or die 'Could not initialize Text::Aspell instance';

	return if ($word =~ /[^a-z0-9'-]/i);
	return if ($Speller->check($word));

	my @Options = $Speller->suggest($word);

	local $_;
	map { $_ = lc($_) } @Options;
	my @CleanOpts;
	while (my $Opt = pop @Options) {
		unshift @CleanOpts, $Opt unless (grep { $_ eq $Opt } @Options);
	}
	@Options = @CleanOpts;
	undef @CleanOpts;
	
	my $OptionCount = settings_get_int('spellcheck_max') || 5;
	$OptionCount = 5 if ($OptionCount < 0);
	@Options = @Options[0..($OptionCount-1)] if ($OptionCount);

	push @$complist, @Options;
}

settings_add_int('misc', 'spellcheck_max', 5);
signal_add_last('complete word' => \&docomplete);
