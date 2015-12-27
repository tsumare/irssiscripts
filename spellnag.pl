use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(signal_add_last settings_add_int settings_get_int);

$VERSION = '1.00';
%IRSSI = (
	authors     => 'Kafan Tsumare',
	contact     => 'github.com/tsumare',
	name        => 'Preprogramed Spelling Correction',
	description => 'Correct people who make really stupid misspellings.',
	license     => 'GPLv3',
);

my %Last;
my $LastClean = time;

sub incoming {
	my ($server, $data, $nick, $address) =@_;
	my ($target, $message) = ($data =~ /^(\S*)\s:(.*)/);

	return unless ($server->{address} =~ /^(?:127|10|192\.168)\./);
	return unless ($target =~ /^#/);

	my $WaitTime = settings_get_int('spellcorrecter_waitseconds');

	if ($LastClean < (time - 600)) {	# Clean every 10 minutes.
		while ( my($Address, $Patterns) = each(%Last) ) {
			while ( my($Pattern, $Time) = each (%$Patterns) ) {
				delete ($Patterns->{$Pattern}) if ($Time <= (time - $WaitTime));
			}
			delete ($Last{$Address}) if (scalar(keys %$Patterns) == 0);
		}
		$LastClean = time;
	}

	my @Patterns = getPatterns($ENV{HOME}.'/.irssi/scripts/spellnag.defs');
	my @Answers;
	
	while (my $Pattern = shift @Patterns) {
		my $Regex = $Pattern->{pattern};

		next unless (	(!exists($Last{$address})) ||
				(!exists($Last{$address}->{$Regex})) ||
				($Last{$address}->{$Regex} <= (time - $WaitTime))
				);

		next unless ($message =~ /$Regex/i);
		push @Answers, { len => length($`), replacement => $Pattern->{replacement} };

		$Last{$address} = {} unless (exists($Last{$address}));
		$Last{$address}->{$Regex} = time;
	}
	return unless (@Answers);
	@Answers = map { $_->{replacement} } sort { $a->{len} <=> $b->{len} } @Answers;

	$server->command(sprintf('^NOTICE %s You may have misspelled %s', $nick, join(', ', @Answers)));
}

{
my %Patterns;
sub getPatterns {
	my $File = shift;
	die sprintf('No such file as "%s"', $File) unless (-f $File);
	die sprintf('Cant read "%s"', $File) unless (-r $File);

	$Patterns{$File} = { ts => (time() + 3600), lines => [] } unless (exists($Patterns{$File}));

	if ($Patterns{$File}->{ts} > time() || $Patterns{$File}->{ts} < ${[stat($File)]}[9]) {
		open(FIL, '<', $File);
		local $_;
		$Patterns{$File}->{lines} = [];
		while (<FIL>) {
			chomp;
			next if (/^#/);
			my @Line = split /\t/, $_, 2;
			$Line[0] =~ s/\\//g;
			push @{$Patterns{$File}->{lines}}, { pattern => $Line[1], replacement => $Line[0] };
		}
	}
	return @{$Patterns{$File}->{lines}};
}
}

signal_add_last('event privmsg' => \&incoming);
settings_add_int('spellcorrecter', 'spellcorrecter_waitseconds', 5);
