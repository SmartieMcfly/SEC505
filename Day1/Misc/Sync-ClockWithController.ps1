#.SYNOPSIS
# Sync clock on member with domain controller to fix kerberos errors.
#
#.NOTES
# When one VM has a virtualization extension or enhancement installed, such as
# VMware Tools, and the other VM does not, then it is more likely that the clocks 
# of the VMs will get out of sync, causing kerberos errors.


# Confirm that the member server gets its NTP time from a controller:

w32tm.exe /config /syncfromflags:domhier /update

Restart-Service -Name w32time


# Show last sync status
"Wait 12 seconds..."
Start-Sleep -Seconds 12
w32tm.exe /query /status | Select-String -Pattern 'successful|source:|NTP'



