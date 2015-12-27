use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(signal_add_last settings_add_bool settings_add_str
                             settings_get_bool settings_get_str);
$VERSION = '1.00';
%IRSSI = (
	authors     => 'Kafan Tsumare',
	contact     => 'github.com/tsumare',
	name        => 'CIDR Tabcomplete',
	description => 'Adds the CIDR and the StartIP-EndIP form of a given CIDR or StartIP-EndIP to the tabcomplete list.',
	license     => 'GPLv3',
);

sub docomplete {
	my ($complist, $window, $word, $linestart, $want_space) = @_;
	local $_ = $word;
	my $OCTET = '\b0*(?:1?\d{1,2}|2(?:[0-4]\d|5[0-5]))\b';
	if 	(m!\b(.*\@)?((?:$OCTET\.)*$OCTET)/(\d|[12]\d|3[0-2])\b!) {
		my $AtPart = $1;
		my $IP = $2;
		my $Bits = $3;
		my $IPs = CIDR_to_IP($IP, $Bits);
		$IPs =~ m!(.+)-(.+)!;
		my $CIDR = IP_to_CIDR($1, $2);

		if ($AtPart) {
			push @$complist, $AtPart . $IPs, $AtPart . $CIDR;
		}
		else {
			push @$complist, $IPs, $CIDR;
		}
	}
	elsif	(/\b(.*\@)?((?:$OCTET\.){3}$OCTET)-((?:$OCTET\.){3}$OCTET)\b/) {
		my $AtPart = $1;
		my $Start = $2;
		my $End = $3;
		my $CIDR = IP_to_CIDR($Start, $End);
		return unless ($CIDR =~ m!(.+)/(\d+)!);
		my $IPs = CIDR_to_IP($1, $2);

		if ($AtPart) {
			push @$complist, $AtPart . $CIDR, $AtPart . $IPs;
		}
		else {
			push @$complist, $CIDR, $IPs;
		}
	}
}

sub CIDR_to_IP {
	my $IP = undot(shift);
	my $Bits = shift;
	my $Netmask = netmask($Bits);
	my $Start = $IP & $Netmask;
	my $End = $Start | (0xFFFFFFFF & ~$Netmask);
	return sprintf('%s-%s', dot($Start), dot($End));
}

sub IP_to_CIDR {
	my $Start = undot(shift);
	my $End = undot(shift);
	my $Bits = common_bits($Start, $End);
	my $Netmask = netmask($Bits);
	my $CIDR = dot($Start & $Netmask);
	
	# Check exactness?
	if (settings_get_bool('cidrtab_exact')) {
		return unless (CIDR_to_IP($CIDR, $Bits) eq sprintf('%s-%s', dot($Start), dot($End)));
	}
	return sprintf("%s/%u", $CIDR, $Bits);
}

sub common_bits {
	my $Start = shift;
	my $End = shift;
	my $Common = ~ ( $Start ^ $End );
	my $i = 0;
	my $curBit = 0x80000000;
	while ($Common & $curBit) {
		$i++;
		$curBit >>= 1;
	}
	return $i;
}

sub netmask {
	my $len = shift;
	return 0xFFFFFFFF & (0xFFFFFFFF << (32 - $len));
}

sub undot {
	my $inIP = shift;
	my @IP = split /\./, $inIP;
	my $IP = 0;
	
	push @IP, 0 while (scalar(@IP) < 4);

	while (defined(my $quad = shift @IP)) {
		$IP = ($IP << 8) | ($quad & 0xFF);
	}
	return $IP;
}

sub dot {
	my $IP = shift;
	return sprintf(	"%u.%u.%u.%u",
			0xFF & ($IP >> 24),
			0xFF & ($IP >> 16),
			0xFF & ($IP >> 8),
			0xFF & $IP
			);
}

signal_add_last('complete word' => \&docomplete);
settings_add_bool 'cidrtab', 'cidrtab_exact' => 0;
