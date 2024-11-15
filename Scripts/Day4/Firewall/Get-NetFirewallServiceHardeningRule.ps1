<#
.SYNOPSIS
   Get the hidden Windows Firewall rules for service hardening.

.DESCRIPTION
   Get the hidden Windows Firewall rules for service hardening and display
   essential properties, such as for piping into Out-GridView.  There are
   Microsoft's "static" service hardening firewall rules, and also the
   "configurable" rules often managed by third-party installer programs.
   Both sets of rules can be directly edited in the registry.  These service
   hardening rules are enforced prior to any rules visible in the Windows
   Firewall MMC.EXE console snap-in.  

.PARAMETER PolicyStore
   Mandatory, must be either "StaticServiceStore" or "ConfigurableServiceStore".

.EXAMPLE
    Get-NetFirewallServiceHardeningRule -PolicyStore StaticServiceStore | Out-GridView

.NOTES
   Reference: https://technet.microsoft.com/en-us/library/cc755191(v=ws.10).aspx
   Legal: 0BSD.
   Author: Jason Fossen, Enclave Consulting LLC (https://www.sans.org/sec505)
   Last Updated: 15.Oct.2020
   Sorry, the cmdlets used run very slowly, not my fault...
#>


[CmdletBinding()] 
Param 
( 
    [ValidateSet("StaticServiceStore","ConfigurableServiceStore")]
    [Parameter(Mandatory=$True)]
    $PolicyStore 
)



Function Get-NetFirewallServiceHardeningRule 
{
    [CmdletBinding()] 
    Param 
    ( 
        [ValidateSet("StaticServiceStore","ConfigurableServiceStore")]
        [Parameter(Mandatory=$True)]
        $PolicyStore 
    )

    $Rules = Get-NetFirewallRule -PolicyStore $PolicyStore 

    ForEach ($rule in $Rules)
    {
        $RuleSummary = [pscustomobject] @{ Name = ""; DisplayName = ""; Action = ""; Direction = ""; Service = "";
                        Protocol = ""; LocalPort = ""; RemotePort = ""; LocalAddress = ""; RemoteAddress = ""; 
                        IcmpType = ""; DynamicTarget = ""; Enabled = ""; Program = ""; Package = ""; Profile = "" } 

        $RuleSummary.Name = $rule.Name
        $RuleSummary.DisplayName = $rule.DisplayName
        $RuleSummary.Enabled = $rule.Enabled
        $RuleSummary.Action = $rule.Action
        $RuleSummary.Direction = $rule.Direction
        $RuleSummary.Profile = $rule.Profile

        $PortFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule 
        $RuleSummary.Protocol = $PortFilter.Protocol
        $RuleSummary.LocalPort = $PortFilter.LocalPort
        $RuleSummary.RemotePort = $PortFilter.RemotePort
        $RuleSummary.IcmpType = $PortFilter.IcmpType
        $RuleSummary.DynamicTarget = $PortFilter.DynamicTarget

        $AddrFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule 
        $RuleSummary.LocalAddress = $AddrFilter.LocalAddress
        $RuleSummary.RemoteAddress = $AddrFilter.RemoteAddress

        $AppFilter = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule 
        $RuleSummary.Program = $AppFilter.Program
        $RuleSummary.Package = $AppFilter.Package 

        $ServiceFilter = Get-NetFirewallServiceFilter -AssociatedNetFirewallRule $rule 
        $RuleSummary.Service = $ServiceFilter.Service

        $RuleSummary
    }

}


Get-NetFirewallServiceHardeningRule -PolicyStore $PolicyStore




<#
Registry location of the StaticServiceStore rules:
    HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System

Registry location of the ConfigurableServiceStore rules:
    HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Configurable\System


If you wish, reading the registry directly is much faster:

    $key = Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System'
    $key.GetValueNames() | ForEach { $key.GetValue($_) } 

But you'll have to parse the fields yourself and expand the indirect strings (see Expand-IndirectStrings.ps1 script).



Block Always Wins? Even for Hidden Rules? Experiment:
Enable the "Remote Event Log Management" group rules.
Enable the "COM+ Network Access" group rule.
The EventLog service is remotely accessible now.
From the StaticServiceStore, delete the Eventlog-1 rule with regedit, the rule that allows inbound to the EventLog service RPC port.
Reboot.
The EventLog service is no longer accessible.
From the StaticServiceStore, delete all the Eventlog-* rules with regedit, including the blocking rules.
Reboot.
The EventLog service is now accessible again.

Why?  Dive into the FW deep end here:
https://docs.microsoft.com/en-us/windows/win32/fwp/filter-arbitration
https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-firewall/filter-origin-documentation
https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-fasp/
https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-gpfas/

Stealth Mode:
https://docs.microsoft.com/en-us/troubleshoot/windows-server/networking/disable-stealth-mode
#>


