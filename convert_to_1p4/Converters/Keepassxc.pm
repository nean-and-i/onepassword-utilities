# Generic CSV converter
#
# Copyright 2015 Mike Cappella (mike@cappella.us)
# adoped by nean for keepasXC CSV exports
#
# 1.) KeepassXC export as CSV
# 2.) copy Keepassxc.pm into Converters folder
# 3.) perl convert_to_1p4.pl keepassxc nean.csv -v
# NOTE: groupname to tag conversation -> tags based on groupfolder will be be assigned every record



package Converters::Keepassxc 1.03;

our @ISA 	= qw(Exporter);
our @EXPORT     = qw(do_init do_import do_export);
our @EXPORT_OK  = qw();

use v5.14;
use utf8;
use strict;
use warnings;
#use diagnostics;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use Utils::PIF;
use Utils::Utils;
use Utils::Normalize;

use Text::CSV;
use Time::Piece;
use Time::Local qw(timelocal);

my %card_field_specs = (
    bankacct =>			{ textname => '', fields => [
	[ 'title',		0, qr/^title$/i, ],
	[ 'bankName',		1, qr/^Bank Name$/i, ],
	[ 'owner',		1, qr/^Owner$/i, ],
	[ 'accountType',	1, qr/^Account Type$/i, ],
	[ 'routingNo',		1, qr/^Routing Number$/i, ],
	[ 'accountNo',		1, qr/^Account Number$/i, ],
	[ 'swift',		1, qr/^SWIFT$/i, ],
	[ 'iban',		1, qr/^IBAN$/i, ],
	[ 'telephonePin',	1, qr/^PIN$/i, ],
	[ 'branchPhone',	0, qr/^Phone$/i, ],
	[ 'branchAddress',	0, qr/^Address$/i, ],
	[ 'notes',		0, qr/^notes$/i, ],
	[ 'tags',		0, qr/^tags$/i, ],
    ]},
    identity =>			{ textname => '', fields => [
	[ 'title',		0, qr/^title$/i, ],
	[ 'firstname',		1, qr/^First Name$/i, ],
	[ 'initial',		1, qr/^Initial$/i, ],
	[ 'lastname',		1, qr/^Last Name$/i, ],
	[ 'sex',		1, qr/^Sex$/i, ],
	[ 'birthdate',		1, qr/^Birth Date$/i, { func => sub { return date2epoch($_[0]) } } ],
	[ 'occupation',		1, qr/^Occupation$/i, ],
	[ 'company',		1, qr/^Company$/i, ],
	[ 'department',		1, qr/^Department$/i, ],
	[ 'jobtitle',		1, qr/^Job Title$/i, ],
	[ '_address',		1, qr/^Address$/i, ],
	[ 'defphone',		1, qr/^Default Phone$/i, ],
	[ 'homephone',		1, qr/^Home Phone$/i, ],
	[ 'cellphone',		1, qr/^Cell Phone$/i, ],
	[ 'busphone',		1, qr/^Business Phone$/i, ],
	[ 'username',		1, qr/^Default Username$/i, ],
	[ 'reminderq',		1, qr/^Reminder Question$/i, ],
	[ 'remindera',		1, qr/^Reminder Answer$/i, ],
	[ 'email',		1, qr/^Email$/i, ],
	[ 'website',		0, qr/^Website$/i, ],
	[ 'icq',		1, qr/^ICQ$/i, ],
	[ 'skype',		1, qr/^Skype$/i, ],
	[ 'aim',		1, qr/^AIM$/i, ],
	[ 'yahoo',		1, qr/^Yahoo$/i, ],
	[ 'msn',		1, qr/^MSN$/i, ],
	[ 'forumsig',		1, qr/^Forum Signature$/i, ],
	[ 'notes',		0, qr/^notes$/i, ],
	[ 'tags',		0, qr/^tags$/i, ],
    ]},
    creditcard =>		{ textname => '', fields => [
	[ 'title',		0, qr/^title$/i, ],
	[ 'ccnum',		1, qr/^card number$/i, ],
	[ 'expiry',		1, qr/^expires$/i, ],
	[ 'cardholder',		1, qr/^cardholder$/i, ],
	[ 'pin',		0, qr/^pin$/i, ],
	[ 'bank',		1, qr/^bank$/i, ],
	[ 'cvv',		1, qr/^cvv$/i, ],
	[ 'notes',		0, qr/^notes$/i, ],
	[ 'tags',		0, qr/^tags$/i, ],
    ]},
    login =>			{ textname => '', fields => [
	[ 'tags',		1, qr/^group$/i, ],
	[ 'title',		0, qr/^title$/i, ],
	[ 'username',		1, qr/^username$/i, ],
	[ 'password',		1, qr/^password$/i, ],
	[ 'url',		1, qr/^url$/i, ],
	[ 'notes',		0, qr/^notes$/i, ],
    ]},
    membership =>		{ textname => '', fields => [
	[ 'title',		0, qr/^title$/i, ],
	[ 'tags',		1, qr/^group$/i, { type_out => 'login' } ],
	[ 'member_name',	1, qr/^member name$/i, ],
	[ 'membership_no',	1, qr/^member id$/i, ],
	[ 'expiry_date',	1, qr/^expiration date$/i,	{ func => sub { return date2monthYear($_[0]) } } ],
	[ 'member_since',	1, qr/^member since$/i,	{ func => sub { return date2monthYear($_[0]) } }],
	[ 'pin',		0, qr/^pin$/i, ],
	[ 'phone',		0, qr/^telephone$/i, ],
	[ 'username',		1, qr/^username$/i, 	{ type_out => 'login' } ],
	[ 'password',		1, qr/^password$/i, 	{ type_out => 'login' } ],
	[ 'url',		1, qr/^url$/i, 	{ type_out => 'login' } ],
	[ 'notes',		0, qr/^notes$/i, { type_out => 'login' } ],
    ]},
    note =>			{ textname => '', fields => [
    ]},
    password =>			{ textname => '', fields => [
	[ 'title',		0, qr/^title$/i, ],
	[ 'url',		1, qr/^password url$/i, ],
	[ 'password',		1, qr/^password$/i, ],
	[ 'notes',		0, qr/^notes$/i, ],
	[ 'tags',		0, qr/^tags$/i, ],
    ]},
    socialsecurity =>		{ textname => '', fields => [
	[ 'title',		0, qr/^title$/i, ],
	[ 'name',		0, qr/^name$/i, ],
	[ 'number',		1, qr/^ss number$/i, ],
    ]},
);

$DB::single = 1;					# triggers breakpoint when debugging

my $custom_field_num = 1;

sub do_init {
    return {
	'specs'		=> \%card_field_specs,
	'imptypes'  	=> undef,
	'opts'		=> [ ],
    }
}

sub do_import {
    my ($file, $imptypes) = @_;

    my $csv = Text::CSV->new ({
	    binary => 1,
	    allow_loose_quotes => 0,
	    sep_char => ',',
	    #eol => "\x{0d}\x{0a}",
    });

    open my $io, "<:encoding(utf8)", $file
	or bail "Unable to open CSV file: $file\n$!";

=cut
    # remove BOM
    my $bom;
    (my $nb = read($io, $bom, 1) == 1 and $bom eq "\x{FEFF}") or
	bail "Failed to read BOM from CSV file: $file\n$!";
=cut

    my $column_names = $csv->getline($io) or
	bail "Failed to parse CSV column names: $!";

    foreach (@$column_names) {
	$_ =~ s/\s*$//;		# be kind - remove any trailing whitespace from column labels
	$_ = lc $_;
    }

    # get the card type, and create a hash of the key field names that maps the column names to column positions
    my ($itype, $col_names_to_pos) = find_card_type($column_names);
    %$col_names_to_pos or
	bail "CSV column names do not match expected names";

    # grab and remove the special field column names
    for (sort { $b <=> $a } values %$col_names_to_pos) {
	splice @$column_names, $_, 1;
    }

    my %Cards;
    my ($n, $rownum) = (1, 1);

    while (my $row = $csv->getline($io)) {
	debug 'ROW: ', $rownum++;
	next if defined $imptypes and (! exists $imptypes->{$itype});

	my (@fieldlist, %cmeta);
	# save the special fields to pass to normalize_card_data below, and then remove them from the row.
	for (keys %$col_names_to_pos) {
	    $cmeta{$_} = $_ eq 'tags' ? [ split(/\s*\/\s*/, $row->[$col_names_to_pos->{$_}]) ] :  $row->[$col_names_to_pos->{$_}];
	}
	# remove the special field values
	for (sort { $b <=> $a } values %$col_names_to_pos) {
	    splice @$row, $_, 1;
	}

	# everything that remains in the row is the field data
	for (my $i = 0; $i <= $#$column_names; $i++) {
	    if ($itype eq 'creditcard' and $column_names->[$i] eq 'expires') {
		$row->[$i] = date2monthYear($row->[$i]);
	    }
	    push @fieldlist, [ $column_names->[$i] => $row->[$i] ];		# retain field order
	}

	my $normalized = normalize_card_data(\%card_field_specs, $itype, \@fieldlist, \%cmeta);
	my $cardlist   = explode_normalized($itype, $normalized);

	for (keys %$cardlist) {
	    print_record($cardlist->{$_});
	    push @{$Cards{$_}}, $cardlist->{$_};
	}
	$n++;
    }
    if (! $csv->eof()) {
	warn "Unexpected failure parsing CSV: row $n";
    }

    summarize_import('item', $n - 1);
    return \%Cards;
}

sub do_export {
    add_custom_fields(\%card_field_specs);
    create_pif_file(@_);
}

sub find_card_type {
    my $row = shift;
    my $otype;
    my %col_names_to_pos;

    for my $type (sort by_test_order keys %card_field_specs) {
	for my $cfs (@{$card_field_specs{$type}{'fields'}}) {
	    for (my $i = 0; $i <= $#$row; $i++) {
		if (defined $cfs->[CFS_MATCHSTR] and $row->[$i] =~ /$cfs->[CFS_MATCHSTR]/ms) {
		    $otype = $type	 			if $cfs->[CFS_TYPEHINT];
		    $col_names_to_pos{$cfs->[CFS_FIELD]} = $i	if $cfs->[CFS_FIELD] =~ /^title|notes|tags$/;
		}
	    }
	}
	last if defined $otype;
    }

    $otype ||= 'note';
    debug "\t\ttype detected as '$otype'";
    return ($otype, \%col_names_to_pos);
}

# sort logins as the last to check
sub by_test_order {
    return  1 if $a eq 'login';
    return -1 if $b eq 'login';
    $a cmp $b;
}


# yyyy-mm-dd or yyyy/mm/dd	for birthdays
# mm/yyyy
# mmyyyy
sub parse_date_string {
    local $_ = $_[0];

    if (s/^(\d{4})[-\/](\d{2})[-\/](\d{2})$/$1-$2-$3/) {
	if (my $t = Time::Piece->strptime($_, "%Y-%m-%d")) {	# KeePass 2 dates are in standard UTC string format
	    return $t;
	}
    }
    else {
	s/\///;
	return undef unless /^\d{6}$/;
	if (my $t = Time::Piece->strptime($_, "%m%Y")) {
	    return $t;
	}
    }

    return undef;
}

sub date2monthYear {
    my $t = parse_date_string @_;
    return defined $t->year ? sprintf("%d%02d", $t->year, $t->mon) : $_[0];
}

sub date2epoch {
    my $t = parse_date_string @_;
    return undef if not defined $t;
    return defined $t->year ? 0 + timelocal(0, 0, 0, $t->mday, $t->mon - 1, $t->year): $_[0];
}

1;