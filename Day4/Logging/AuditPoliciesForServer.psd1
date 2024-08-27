<#
This is a hashtable of Windows audit policies for use with
the Set-AdvancedAuditPolicy.ps1 script.  See that script.

There must be exactly 59 keys in the hashtable for the 59 policies.

The only permissible value for each key of the hashtable is one of 
these four options:

    Success
    Failure
    Success Failure
    No Auditing

The values are not case sensitive.  

There should be no leading or trailing space characters for the keys or values.

When used, there must be one space character in "Success Failure" or "No Auditing".

Microsoft periodically updates and publishes a spreadsheet of recommended
audit policies for its various operating systems.  Search Microsoft's website 
for "Microsoft Security Compliance Toolkit" for the latest download URL.  

The following sets the audit policies as recommended for Windows 10 and 
Windows Server 2016, but feel free to copy and edit as desired.
#>



@{
#System
'Security System Extension'              = 'Success Failure'
'System Integrity'                       = 'Success Failure'
'IPSec Driver'                           = 'Success Failure'
'Other System Events'                    = 'Success Failure'
'Security State Change'                  = 'Success'

#Logon/Logoff
'Logon'                                  = 'Success Failure'
'Logoff'                                 = 'Success'
'Account Lockout'                        = 'Success Failure'
'IPSec Main Mode'                        = 'No Auditing'
'IPSec Quick Mode'                       = 'No Auditing'
'IPSec Extended Mode'                    = 'No Auditing'
'Special Logon'                          = 'Success'
'Other Logon/Logoff Events'              = 'No Auditing'
'Network Policy Server'                  = 'No Auditing'
'User / Device Claims'                   = 'No Auditing'
'Group Membership'                       = 'Success'

#Object Access
'File System'                            = 'No Auditing'
'Registry'                               = 'No Auditing'
'Kernel Object'                          = 'No Auditing'
'SAM'                                    = 'No Auditing'
'Certification Services'                 = 'No Auditing'
'Application Generated'                  = 'No Auditing'
'Handle Manipulation'                    = 'No Auditing'
'File Share'                             = 'No Auditing'
'Filtering Platform Packet Drop'         = 'No Auditing'
'Filtering Platform Connection'          = 'No Auditing'
'Other Object Access Events'             = 'No Auditing'
'Detailed File Share'                    = 'No Auditing'
'Removable Storage'                      = 'Success Failure'
'Central Policy Staging'                 = 'No Auditing'

#Privilege Use
'Non Sensitive Privilege Use'            = 'No Auditing'
'Other Privilege Use Events'             = 'No Auditing'
'Sensitive Privilege Use'                = 'Success Failure'

#Detailed Tracking
'Process Creation'                       = 'Success'
'Process Termination'                    = 'No Auditing'
'DPAPI Activity'                         = 'No Auditing'
'RPC Events'                             = 'No Auditing'
'Plug and Play Events'                   = 'Success'
'Token Right Adjusted Events'            = 'No Auditing'

#Policy Change
'Audit Policy Change'                    = 'Success Failure'
'Authentication Policy Change'           = 'Success'
'Authorization Policy Change'            = 'Success'
'MPSSVC Rule-Level Policy Change'        = 'No Auditing'
'Filtering Platform Policy Change'       = 'No Auditing'
'Other Policy Change Events'             = 'No Auditing'

#Account Management
'Computer Account Management'            = 'Success'
'Security Group Management'              = 'Success Failure'
'Distribution Group Management'          = 'No Auditing'
'Application Group Management'           = 'No Auditing'
'Other Account Management Events'        = 'Success Failure'
'User Account Management'                = 'Success Failure'

#DS Access
'Directory Service Access'               = 'Success Failure'
'Directory Service Changes'              = 'Success Failure'
'Directory Service Replication'          = 'No Auditing'
'Detailed Directory Service Replication' = 'No Auditing'

#Account Logon
'Kerberos Service Ticket Operations'     = 'No Auditing'
'Other Account Logon Events'             = 'No Auditing'
'Kerberos Authentication Service'        = 'No Auditing'
'Credential Validation'                  = 'Success Failure'
} 
