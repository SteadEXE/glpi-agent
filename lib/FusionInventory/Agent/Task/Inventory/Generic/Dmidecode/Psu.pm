package FusionInventory::Agent::Task::Inventory::Generic::Dmidecode::Psu;

use strict;
use warnings;

use parent 'FusionInventory::Agent::Task::Inventory::Module';

use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::Generic;
use FusionInventory::Agent::Tools::PartNumber;

sub isEnabled {
    my (%params) = @_;
    return 0 if $params{no_category}->{psu};
    return 1;
}

my %fields = (
    PARTNUM         => 'Model Part Number',
    SERIALNUMBER    => 'Serial Number',
    MANUFACTURER    => 'Manufacturer',
    NAME            => 'Name',
    STATUS          => 'Status',
    PLUGGED         => 'Plugged',
    LOCATION        => 'Location',
    POWER_MAX       => 'Max Power Capacity',
    HOTREPLACEABLE  => 'Hot Replaceable',
);

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};

    my $infos = getDmidecodeInfos(%params);

    return unless $infos->{39};

    foreach my $info (@{$infos->{39}}) {
        # Skip battery
        next if $info->{'Type'} && $info->{'Type'} eq 'Battery';

        my $psu;

        # Add available informations but filter out not filled values
        foreach my $key (keys(%fields)) {
            next unless defined($info->{$fields{$key}});
            next if $info->{$fields{$key}} =~ /To Be Filled By O.?E.?M/i;
            next if $info->{$fields{$key}} =~ /OEM Define/i;
            $psu->{$key} = $info->{$fields{$key}};
        }

        # Get canonical manufacturer
        $psu->{'MANUFACTURER'} = getCanonicalManufacturer($psu->{'MANUFACTURER'})
            if $psu->{'MANUFACTURER'};

        # Validate PartNumber, as example, this fixes Dell PartNumbers
        if ($psu->{'PARTNUM'} && $psu->{'MANUFACTURER'}) {
            my $partnumber_factory = FusionInventory::Agent::Tools::PartNumber->new(
                logger  => $params{logger},
            );
            my $partnumber = $partnumber_factory->match(
                partnumber      => $psu->{'PARTNUM'},
                manufacturer    => $psu->{'MANUFACTURER'},
                category        => "controller",
            );
            $psu->{'PARTNUM'} = $partnumber->get
                if defined($partnumber);
        }

        # Filter out PSU if nothing interesting is found
        next unless $psu;
        next unless ($psu->{'NAME'} || $psu->{'SERIALNUMBER'} || $psu->{'PARTNUM'});

        $inventory->addEntry(
            section => 'POWERSUPPLIES',
            entry   => $psu
        );
    }
}

1;
