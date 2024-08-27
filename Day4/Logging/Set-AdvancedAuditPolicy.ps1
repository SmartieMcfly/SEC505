<################################################################################
.SYNOPSIS
  Manage the Windows Advanced Audit Policies using the AUDITPOL.EXE tool.

.DESCRIPTION
  This script can display or disable all Advanced Audit Policies.  If given the
  path to a PSD1 file, then the policies defined in that PSD1 file will be enabled.
  See the sample AuditPoliciesForServer.psd1 file in this folder.

  WARNING: This script disables all audit policies first, then only enables
  the audit policies defined in the PSD1 file.  This script does not append to
  the existing policies, it overwrites all existing audit policies.  
  
  If the -ShowAuditPolicies switch is used, then no changes are made.

.PARAMETER Path
  Path to the PSD1 file with the desired audit policies to enable. The PSD1
  file must have exactly 59 keys defined.  Each key is the name of an
  Advanced Audit Policy as understood by auditpol.exe.  The value for each
  key must be one of the four following strings exactly:

        Success
        Failure
        Success Failure
        No Auditing

.PARAMETER DisableAllAuditPolicies
  Disables all audit policies and exits.  No audit policies will be enabled.
  Current audit policies are not backed up.  Run "auditpol.exe /backup /?"
  to see how to export the current audit policies to a CSV file.  

.PARAMETER ShowCurrentPolicies
  Displays current advanced audit policies only.  Nothing is changed.

.PARAMETER ShowCommands
  Displays the various auditpol.exe commands as they are being run.
  Useful when debugging.

.NOTES
    Legal: 0BSD.
   Course: SANS SEC505: Securing Windows and PowerShell Automation
 SANS URL: https://www.sans.org/sec505
   Author: Jason Fossen, Enclave Consulting LLC
  Updated: 18.Jul.2017 
################################################################################>

Param ( [Switch] $DisableAllAuditPolicies, [Switch] $ShowCurrentPolicies, [Switch] $ShowCommands, $Path) 


# Check path to auditpol.exe:
$AuditPolExePath = Resolve-Path -Path "$env:WinDir\System32\auditpol.exe" | Select -ExpandProperty Path

if (-not $? -or $AuditPolExePath.Length -lt 8)
{ 
    Write-Error -Message "Cannot Find AUDITPOL.EXE"
    Exit 
} 


# Display current policies and quit?
if ($ShowCurrentPolicies)
{ 
    auditpol.exe /get /category:* | Select-String -Pattern 'Success|Failure|No Auditing' 
    Exit
} 




if ($DisableAllAuditPolicies)
{ 
    # To suppress all console output in powershell.exe, a couple temp files are needed:
    $tempfile1 = Join-Path -Path $env:TEMP -ChildPath ([string](get-date).ticks + '.tmp1') 
    $tempfile2 = Join-Path -Path $env:TEMP -ChildPath ([string](get-date).ticks + '.tmp2') 

    if ($ShowCommands){ "$AuditPolExePath /clear /y" } 
    #-Wait is needed or else the temp files are created after the Remove-Item command to delete them.
    Start-Process -FilePath $AuditPolExePath -ArgumentList '/clear /y' -NoNewWindow -RedirectStandardError $tempfile1 -RedirectStandardOutput $tempfile2 -Wait
    Remove-Item -Path $tempfile1,$tempfile2 -Force -ErrorAction SilentlyContinue
    Exit 
} 


# Try to import the PSD1 with the policies
$AuditPolicyList = Import-PowerShellDataFile -Path $Path -ErrorAction Stop 


# Check for 59 policies exactly (has the number of advanced audit policies changed from 59?).
# See:  auditpol.exe /get /category:* | Select-String -Pattern 'Success|Failure|No Auditing' | Measure-Object
if ($AuditPolicyList.Count -ne 59)
{ Write-Error -Message "Wrong count of audit policies in the PSD1 file, there must be 59 exactly" ; Exit }


# Check every value for legal strings:
ForEach ($key in $AuditPolicyList.Keys)
{
    if ($AuditPolicyList.$key -notmatch '^Success$|^Failure$|^Success Failure$|^Success and Failure$|^No Auditing$')
    { 
        Write-Verbose -Verbose -Message "Each audit policy in the PSD1 file may only be set to one of the following four choices: `nSuccess `nFailure `nSuccess Failure `nNo Auditing"
        Write-Error -Message "$key = $AuditPolicyList.$key is not allowed or is formatted incorrectly"
        Exit
    }
}


#TODO: Check every audit policy name against a validation list or just let auditpol.exe complain? 


# To suppress all console output in powershell.exe, a couple temp files are needed:
$tempfile1 = Join-Path -Path $env:TEMP -ChildPath ([string](get-date).ticks + '.tmp1') 
$tempfile2 = Join-Path -Path $env:TEMP -ChildPath ([string](get-date).ticks + '.tmp2') 


# OK, assume good to go, disable all existing audit policies:
if ($ShowCommands){ "$AuditPolExePath /clear /y" } 
#-Wait is not used here, the temp files are deleted later
Start-Process -FilePath $AuditPolExePath -ArgumentList '/clear /y' -NoNewWindow -RedirectStandardError $tempfile1 -RedirectStandardOutput $tempfile2


# Construct args for auditpol.exe and run:
ForEach ($Policy in $AuditPolicyList.Keys)
{
    # No Auditing
    if ($AuditPolicyList.$Policy -eq 'No Auditing'){ Continue } 

    # Success, Failure, Success Failure, and, unofficially, Success and Failure
    $EndingArgs = ''
    if ($AuditPolicyList.$Policy -eq 'Success'){ $EndingArgs = '/success:enable' } 
    if ($AuditPolicyList.$Policy -eq 'Failure'){ $EndingArgs = '/failure:enable' } 
    if ($AuditPolicyList.$Policy -like 'Success*Failure'){ $EndingArgs = '/success:enable /failure:enable' } 
    $EndingArgs = '/set /subcategory:"' + $Policy.Trim() + '" ' + $EndingArgs

    # Run auditpol.exe with the arguments for each audit policy:
    if ($ShowCommands){ "$AuditPolExePath $EndingArgs" } 
    #-Wait is not used here, it is too slow and not needed to del the temp files
    Start-Process -FilePath $AuditPolExePath -ArgumentList $EndingArgs -NoNewWindow -RedirectStandardError c:\temp\x2.txt -RedirectStandardOutput c:\temp\x1.txt 
}


# Clean up any temp files
Start-Sleep -Milliseconds 23
Remove-Item -Path $tempfile1,$tempfile2 -Force -ErrorAction SilentlyContinue

# END