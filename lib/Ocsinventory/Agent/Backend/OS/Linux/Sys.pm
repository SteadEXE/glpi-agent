package Ocsinventory::Agent::Backend::OS::Linux::Sys;

#$LunchAfter = "Ocsinventory::Agent::Backend::OS::Linux::VirtualFs::Sys";

sub isInventoryEnabled {
  return unless can_run ("mount");
  foreach (`mount`) {
    return 1 if (/type\ sysfs/);
  }
  0;
}

sub doInventory {}

1
