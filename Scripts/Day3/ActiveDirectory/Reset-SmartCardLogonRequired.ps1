<#
.SYNOPSIS
Toggles the "require a smart card" attribute on user accounts off/on.

.DESCRIPTION
On the Account tab in the properties of a user account in AD there is a 
checkbox labeled "Require a smart card for interactive logon".  If this
box is checked for a user, then this script will uncheck and recheck it.
Defaults to every user in the domain whose account is set to "Require a
smart card for interactive logon", but the DN path to a specific OU may 
be targeted instead.  The Success property on the objects outputted by 
the script indicates whether the change was successful on each user.  
The TimeStamp property is the ticks time when the change was attempted.  
Script must be run by a Domain Admins member or a similar account with 
write access to the userAccountControl property of each target user.

.PARAMETER SearchBase
The distinguished name path to an Organizational Unit (OU) where the
search will begin to find user accounts that must log on with a smart
card.  The default search base is the entire local AD domain.

.NOTES
To convert a ticks number to a DateTime object: "<tick> | Get-Date".

Version: 1.1
Legal: 0BSD.
Author: Enclave Consulting LLC, Jason Fossen, https://sans.org/sec505
#>

Param ( $SearchBase = $null )


# Get the AD domain or OU to search:
# (Note that the built-in "$?" variable will be $True when the prior
# command succeeds or $False when the prior command raises an error.)

if ( $SearchBase -eq $null ) 
{ 
    $SearchBase = Get-ADDomain -Current LoggedOnUser -ErrorAction Stop
    if (!$?){ exit }  
} 
else
{ 
    $SearchBase = Get-ADOrganizationalUnit -Identity $SearchBase -ErrorAction Stop
    if (!$?){ exit } 
}


# Find target users and toggle their smart card required property:

Get-ADUser -Filter { SmartCardLogonRequired -eq $True } -SearchBase $SearchBase |
ForEach {
    #Toggle the smart card checkbox off and on again:
    Set-ADUser -Identity $_ -SmartcardLogonRequired $False -ErrorAction SilentlyContinue
    Set-ADUser -Identity $_ -SmartcardLogonRequired $True -ErrorAction SilentlyContinue
    
    #Did the last command work?
    if ($?){ $Success = $True } else { $Success = $False }

    #Create new object to output with a Success property to indicate whether the toggling worked:
    $output = $_ | Select-Object -Property Success,TimeStamp,SamAccountName,UserPrincipalName,DistinguishedName
    $output.TimeStamp = (Get-Date).Ticks
    $output.Success = $Success
    $output
}



