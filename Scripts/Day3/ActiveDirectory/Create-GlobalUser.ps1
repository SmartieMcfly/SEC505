##############################################################################
#.SYNOPSIS
#   Create a global/domain user account in AD using .NET classes directly.
#.NOTES
#    Date: 10.Sep.2007
# Version: 1.1
#  Author: Jason Fossen, Enclave Consulting LLC
#   Legal: 0BSD
##############################################################################


param ($UserName, $Container = "CN=Users", $Domain = "")


function Create-GlobalUser ($UserName, $Container = "CN=Users", $Domain = "") 
{ 
    # Get domain object specified, or the local domain if blank.
    $DirectoryEntry = new-object System.DirectoryServices.DirectoryEntry -arg $Domain
    
    # Construct LDAP path to the container which will hold the new user.
    $PathToContainer = "LDAP://$Container," + "$($DirectoryEntry.DistinguishedName)"
    
    # Get the collection of objects in the container so we can add to the collection.
    $Container = new-object System.DirectoryServices.DirectoryEntry -arg $PathToContainer
    $DirectoryEntries = $Container.PSbase.Children
    
    # Add a user account to the container, set its username, save changes.
    $User = $DirectoryEntries.Add('CN=' + $UserName, 'User')    
    $User.PSbase.InvokeSet('sAMAccountName', $UserName)
    $User.PSbase.CommitChanges()
    
    # Enable the new user account, save changes.
    $User.PSbase.InvokeSet('AccountDisabled', 'False')
    $User.PSbase.CommitChanges()

    # Tell the .NET Garbage Collector that we're done with the object.
    # Strictly speaking, this isn't necessary, but good to be tidy!
    $User.PSbase.Dispose() 
}


create-globaluser -username $username -container $container -domain $domain

