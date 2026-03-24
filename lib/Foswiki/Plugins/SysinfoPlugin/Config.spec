# ---+ Extensions
# ---++ SysinfoPlugin

# **COMMAND LABEL="Disk Free Command" EXPERT**
$Foswiki::cfg{SysinfoPlugin}{DiskFreePathCmd} = '/usr/bin/df --block-size=%BLOCKSIZE|N%';

# **BOOLEAN LABEL="AdminOnly"**
# if enabled only users with admin rights may execute sysinfo commands.
$Foswiki::cfg{SysinfoPlugin}{AdminOnly} = 1;

1;
