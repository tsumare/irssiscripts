use strict;
use vars qw($VERSION %IRSSI);
use Data::Dumper;

use Irssi qw(signal_add_last settings_add_bool settings_get_bool settings_add_int settings_get_int);
use Text::Aspell qw();

$VERSION = '1.00';
%IRSSI = (
	authors     => 'Kafan Tsumare',
	contact     => 'github.com/tsumare',
	name        => 'Identify on Join',
	description => 'Identify users on join who had previously visited.',
	license     => 'GPLv3',
);

my %History;
my %Current;

sub onjoin {
	my ($server, $channame, $nick, $identhost) = @_;
	my ($ident, $host) = ($identhost =~ /^([^@]+)@(.+)$/);

	purge();

	my %ThisUser = ( nicks => [ $nick ], ident => $ident, host => $host, ts => time() );

	# Initialize current records.
	$Current{$server->{tag}} = {} unless (exists($Current{$server->{tag}}));
	$Current{$server->{tag}}->{lc($channame)} = {} unless (exists($Current{$server->{tag}}->{lc($channame)}));

	# Load current records.
	$Current{$server->{tag}}->{lc($channame)}->{lc($nick)} = \%ThisUser;

	# Initialize historical records.
	$History{$server->{tag}} = {} unless (exists($History{$server->{tag}}));
	$History{$server->{tag}}->{lc($channame)} = {} unless (exists($History{$server->{tag}}->{lc($channame)}));
	my $ChanRec = $History{$server->{tag}}->{lc($channame)};

	# Load historical records by ident@*.host
	$ChanRec->{lc($host)} = [] unless (defined($ChanRec->{lc($host)}));
	push @{$ChanRec->{lc($host)}}, \%ThisUser;

	# Load historical records by host
	my $MaskedHost = sprintf("%s@%s", $ident, uncloaked($host));
	$ChanRec->{lc($MaskedHost)} = [] unless (defined($ChanRec->{lc($MaskedHost)}));
	push @{$ChanRec->{lc($MaskedHost)}}, \%ThisUser;



	# Prepare to print our carefully collected data!
	my @Entries;
	push @Entries, @{$ChanRec->{lc($host)}};
	push @Entries, @{$ChanRec->{lc($MaskedHost)}};
	@Entries = sortEntries(@Entries);

	my @Output;
	my $RemainingEntries = settings_get_int('join_history_max_entries') || 5;

	while ( ($RemainingEntries-- > 0) && (my $Entry = pop @Entries) ) {
		my @Nicks = @{$Entry->{nicks}};

		next if ($Entry == \%ThisUser);	# Do not print an entry for this join.

		unless (settings_get_bool('join_history_duplicate_nicks')) {
			my @AllNicks = @Nicks;
			@Nicks = ();
			while (my $Nick = shift @AllNicks) {
				push @Nicks, $Nick unless (grep { lc($Nick) eq lc($_) } @Nicks);
			}
		}
		unshift @Output, sprintf(	"On %s, %s@%s visited as %s",
						scalar(localtime($Entry->{ts})),
						$Entry->{ident},
						$Entry->{host},
						join(', ', @Nicks)
						);
	}

	my $Channel = $server->window_item_find($channame);
	while (my $Message = shift @Output) {
		$Channel->print($Message, MSGLEVEL_CLIENTCRAP | MSGLEVEL_NO_ACT);
	}
}

sub sortEntries {
	my @Entries;

	while (my $Entry = shift @_) {
		next if (grep { $_ == $Entry } @Entries);	# Drop duplicates.
		push @Entries, $Entry;
	}
	return sort { $a->{ts} <=> $b->{ts} } @Entries;
}

sub onnick {
	my ($server, $newnick, $nick, $identhost) = @_;
	my ($ident, $host) = ($identhost =~ /^([^@]+)@(.+)$/);
	
	return unless (exists($Current{$server->{tag}}));
	
	while ( my($Channel, $Nicks) = each(%{$Current{$server->{tag}}}) ) {
		next unless exists($Nicks->{lc($nick)});
		push @{$Nicks->{lc($nick)}->{nicks}}, $newnick;
		$Nicks->{lc($nick)}->{ts} = time();
		$Nicks->{lc($newnick)} = $Nicks->{lc($nick)};
		delete($Nicks->{lc($nick)});
	}

	#purge();
}

sub onquit {
	my ($server, $nick, $identhost, $reason) = @_;
	my ($ident, $host) = ($identhost =~ /^([^@]+)@(.+)$/);
	
	return unless (exists($Current{$server->{tag}}));

	while ( my($Channel, $Nicks) = each(%{$Current{$server->{tag}}}) ) {
		next unless (exists($Nicks->{lc($nick)}));
		$Nicks->{lc($nick)}->{ts} = time();
		delete($Nicks->{lc($nick)});
	}

	purge();
}

sub onpart {
	my ($server, $channame, $nick, $identhost, $reason) = @_;
	my ($ident, $host) = ($identhost =~ /^([^@]+)@(.+)$/);
	
	return unless (exists($Current{$server->{tag}}));
	return unless (exists($Current{$server->{tag}}->{lc($channame)}));
	return unless (exists($Current{$server->{tag}}->{lc($channame)}->{lc($nick)}));

	$Current{$server->{tag}}->{lc($channame)}->{lc($nick)}->{ts} = time();
	delete($Current{$server->{tag}}->{lc($channame)}->{lc($nick)});

	purge();
}

sub onkick {
	my ($server, $channame, $nick, $kicker, $identhost, $reason) = @_;
	my ($ident, $host) = ($identhost =~ /^([^@]+)@(.+)$/);	# Whose identhost?
	
	return unless (exists($Current{$server->{tag}}));
	return unless (exists($Current{$server->{tag}}->{lc($channame)}));
	return unless (exists($Current{$server->{tag}}->{lc($channame)}->{lc($nick)}));

	$Current{$server->{tag}}->{lc($channame)}->{lc($nick)}->{ts} = time();
	delete($Current{$server->{tag}}->{lc($channame)}->{lc($nick)});

	purge();
}

sub uncloaked {
	my $host = shift;
	if	(/^([0-9A-F]{6}\.){3}[0-9A-F]{6}$/) {	# IP
		$host =~ s/\.[0-9A-F]{6}$//;
	}
	elsif	(/\.[^\.]+\.[^\.]+$/)	{	# HOST (3 part or greater)
		$host =~ s/^[\.]+\.//;
	}
	return $host;
}

sub purge {
	my $MaxEntries = settings_get_int('join_history_max_entries') || 5;
	my $MaxAge = settings_get_int('join_history_max_age') || 86400;

	# Purge historical data that is outside of the limits.
	while ( my($Server, $Channels) = each(%History) ) {
		while ( my($Channel, $Hosts) = each(%$Channels) ) {
			while ( my($Host, $Entries) = each(%$Hosts) ) {
				while (my $Earliest = shift @$Entries) {
					if ( ((time() - $Earliest->{ts}) <= $MaxAge) && (scalar(@$Entries) < $MaxEntries) ) {
						unshift @$Entries, $Earliest;
						last;
					}
				}
				delete $Hosts->{$Host} if (scalar(@$Entries) == 0);	# delete Host if no Entries
			}
			delete $Channels->{$Channel} if (scalar(keys %$Hosts) == 0);	# delete Channel if no Hosts
		}
		delete $History{$Server} if (scalar(keys %$Channels) == 0);		# delete Server if no Channels
	}

	# Purge current data for which no user exists.
	while ( my($Server, $Channels) = each(%Current) ) {
		my $ServerRec = Irssi::server_find_tag($Server);
		unless ($ServerRec) {
			delete($Current{$Server});
			next;
		}
		while ( my($Channel, $Nicks) = each(%$Channels) ) {
			my $Channel = $ServerRec->channel_find($Channel);
			next unless ($Channel->{synced});
			my @chanNicks = $Channel->nicks();
			my %NicksToDel;

			for my $Nick (keys %$Nicks) {
				$NicksToDel{$Nick} = 1;
			}
			for my $Nick (@chanNicks) {
				delete($NicksToDel{$Nick}) if (exists($NicksToDel{$Nick}));
			}
			for my $Nick (keys %NicksToDel) {
				delete($Nicks->{$Nick});
			}
			delete ($Channels->{$Channel}) if (scalar(keys %$Nicks) == 0);
		}
		delete ($Current{$Server}) if (scalar(keys %$Channels) == 0);
	}
}

settings_add_int('join_history', 'join_history_max_entries', 5);
settings_add_int('join_history', 'join_history_max_age', 86400);
settings_add_bool('join_history', 'join_history_duplicate_nicks', 0);
signal_add_last('message join' => \&onjoin);
signal_add_last('message nick' => \&onnick);
signal_add_last('message part' => \&onpart);
signal_add_last('message quit' => \&onquit);
signal_add_last('message kick' => \&onkick);
#Irssi::print(Dumper(\%Current),MSGLEVEL_CLIENTCRAP|MSGLEVEL_NO_ACT);
