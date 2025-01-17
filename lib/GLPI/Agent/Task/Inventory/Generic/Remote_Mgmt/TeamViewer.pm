package GLPI::Agent::Task::Inventory::Generic::Remote_Mgmt::TeamViewer;

use strict;
use warnings;

use parent 'GLPI::Agent::Task::Inventory::Module';

use English qw(-no_match_vars);

use GLPI::Agent::Tools;

sub isEnabled {
    my (%params) = @_;

    if (OSNAME eq 'MSWin32') {

        GLPI::Agent::Tools::Win32->use();

        # Depending on the installation the teamviewer key can be in two place in X64 OS

        my $key = getRegistryKey(
            path => "HKEY_LOCAL_MACHINE/SOFTWARE/TeamViewer",
            # Important for remote inventory optimization
            required    => [ qw/ClientID/ ],
            maxdepth    => 1,
            logger => $params{logger}
        );
        if (!$key && is64bit()) {
            $key = getRegistryKey(
                path => "HKEY_LOCAL_MACHINE/SOFTWARE/Wow6432Node/TeamViewer",
                # Important for remote inventory optimization
                required    => [ qw/ClientID/ ],
                maxdepth    => 1,
                logger => $params{logger}
            );
        }

        return $key && (keys %$key);
    } elsif (OSNAME eq 'darwin') {
        return canRun('defaults') && Glob(
            "/Library/Preferences/com.teamviewer.teamviewer*.plist"
        );
    }

    return canRun('teamviewer');
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{logger};

    my $teamViewerID = _getID(logger => $logger);
    if (defined($teamViewerID)) {
        $logger->debug('Found TeamViewerID : ' . $teamViewerID) if ($logger);

        $inventory->addEntry(
            section => 'REMOTE_MGMT',
            entry   => {
                ID   => $teamViewerID,
                TYPE => 'teamviewer'
            }
        );
    } else {
        $logger->debug('TeamViewerID not found') if ($logger);
    }
}

sub _getID {
    my (%params) = @_;

    if (OSNAME eq 'MSWin32') {

        GLPI::Agent::Tools::Win32->use();

        my $clientid = getRegistryKeyValue(
            path => "HKEY_LOCAL_MACHINE/SOFTWARE/TeamViewer/ClientID",
        );
        if (!$clientid && is64bit()) {
            $clientid = getRegistryKeyValue(
                path => "HKEY_LOCAL_MACHINE/SOFTWARE/Wow6432Node/TeamViewer/ClientID",
            );
        }

        unless ($clientid) {
            my $teamviever_reg = getRegistryKey(
                path => "HKEY_LOCAL_MACHINE/SOFTWARE/TeamViewer",
                # Important for remote inventory optimization
                required    => [ qw/ClientID/ ],
            );
            if(!$teamviever_reg && is64bit()){
                $teamviever_reg = getRegistryKey(
                    path => "HKEY_LOCAL_MACHINE/SOFTWARE/Wow6432Node/TeamViewer",
                    # Important for remote inventory optimization
                    required    => [ qw/ClientID/ ],
                );
            }

            # Look for subkey beginning with Version
            foreach my $key (keys(%{$teamviever_reg})) {
                next unless $key =~ /^Version\d+\//;
                $clientid = $teamviever_reg->{$key}->{"/ClientID"};
                last if (defined($clientid));
            }
        }

        return hex2dec($clientid);
    }

    if (OSNAME eq 'darwin') {
        my ( $plist_file ) = Glob(
            "/Library/Preferences/com.teamviewer.teamviewer*.plist"
        );

        return getFirstLine( command => "defaults read $plist_file ClientID" ) ;
    }

    return getFirstMatch(
        command => "teamviewer --info",
        pattern => qr/TeamViewer ID:(?:\033\[0m|\s)*(\d+)\s+/,
        %params
    );
}

1;
