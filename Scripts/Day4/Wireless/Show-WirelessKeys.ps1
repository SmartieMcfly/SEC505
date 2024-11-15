####################################################################################
#.Synopsis 
#    Displays wireless SSID names and their preshared keys in plaintext.
#
#.Description
#    Displays wireless SSID names and their preshared keys in plaintext.
#    Requires Windows 7 or later.  Must be run with administrative privileges.
#    The script is just a wrapper for NETSH.EXE.
#
#.Example 
#    Show-WirelessKeys.ps1
#
#Requires -Version 2.0 
#
#.Notes 
#  Author: Jason Fossen, Enclave Consulting LLC (http://www.sans.org/sec505) 
# Version: 1.0
# Updated: 24.Jul.2013
#   Legal: 0BSD.
####################################################################################


filter extract-text ($RegularExpression) 
{ 
    select-string -inputobject $_ -pattern $regularexpression -allmatches | 
    select-object -expandproperty matches | 
    foreach { 
        if ($_.groups.count -le 1) { if ($_.value){ $_.value } } 
        else 
        {  
            $submatches = select-object -input $_ -expandproperty groups 
            $submatches[1..($submatches.count - 1)] | foreach { if ($_.value){ $_.value } } 
        } 
    }
}



$SSID = @{}

netsh.exe wlan show profiles | extract-text ': (.+)' | 
foreach { $SSID.add($_,$(netsh.exe wlan show profiles $_ key=clear)) } 

$SSID.keys | foreach { `
	$keycontent = $SSID."$_" | extract-text 'Key Content.+: (.+)' 
	if ($keycontent.length -ge 1) { $_ + " : " + $keycontent }
}

