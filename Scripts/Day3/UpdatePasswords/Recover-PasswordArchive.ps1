﻿####################################################################################
#.Synopsis 
#    Recover the plaintext password from an encrypted file originally
#    created with the companion script named Update-PasswordArchive.ps1. 
#
#.Description 
#    Recover the plaintext password from an encrypted file originally
#    created with the companion script named Update-PasswordArchive.ps1. The
#    file is encrypted with a public key chosen by the administrator. The
#    password generated by Update-PasswordArchive.ps1 is random.  Recovery
#    of the encrypted password from the file requires possession of the
#    private key corresponding to the chosen public key certificate.  (Note
#    that CNG key storage providers are not supported, hence, do not use the
#    Microsoft Software Key Storage Provider in the template for the original
#    certificate request.)  
#
#.Parameter PasswordArchivePath 
#    The local or UNC path to where the encrypted password files are kept. 
#
#.Parameter ComputerName
#    Name of the computer with the local account whose password was reset
#    and whose password was encrypted and saved to a file.  The computer
#    name will match the names of files in the PasswordArchivePath.  This
#    parameter can accept a computer name with a wildcard in it.
#
#.Parameter UserName
#    Name of the local user account whose password was reset and whose password
#    was encrypted and saved to a file.  The username will match the names of
#    files in the PasswordArchivePath.  Default is "Administrator".  If you
#    are not certain, just enter "*" and the last reset will be used, whatever
#    username that may be, or you might use the -ShowAll switch instead.
#
#.Parameter ShowAll
#    Without this switch, only the most recent plaintext password is shown.
#    With this switch, all archived passwords for the computer are shown.
#    This might be necessary when the passwords of multiple local user 
#    accounts are being managed with these scripts.
#
#
#.Example 
#    .\Recover-PasswordArchive.ps1 -ComputerName LAPTOP47 -UserName Administrator
#
#    Displays in plaintext the last recorded password updated on LAPTOP47.
#    The user running this script must have loaded into their local cache
#    the certificate AND private key corresponding to the certificate used
#    to originally encrypt the password archive files in the present
#    working directory.  A smart card may be used instead.  The default 
#    username is "Administrator", so this argument was not actually required.
#
#.Example 
#    .\Recover-PasswordArchive.ps1 -PasswordArchivePath \\server\share -ComputerName WKS*
#
#    Instead of the present working directory of the script, search the
#    password archive files located in \\server\share.  Another local
#    folder can be specified instead of a UNC network path.  The wildcard
#    in the computer name will show the most recent password updates for
#    all matching computer names in \\server\share for the Administrator.
# 
#.Example 
#    .\Recover-PasswordArchive.ps1 -PasswordArchivePath \\server\share -ComputerName LAPTOP47 -ShowAll
#
#    Instead of showing only the last password update for the Administrator account, 
#    show all archived passwords in the \\server\share folder for LAPTOP47.
#
# 
#Requires -Version 2.0 
#
#.Notes 
#  Author: Jason Fossen, Enclave Consulting LLC (http://www.sans.org/sec505)  
# Version: 5.2
# Updated: 10.Jul.2015
#   Legal: 0BSD.
####################################################################################

Param ($PasswordArchivePath = ".\", $ComputerName = "$env:computername", $UserName = "Guest", [Switch] $ShowAll) 


# Rijndael decryption function used after $Key is decrypted with private key of cert.
# Why not use AES explicitly?  That requires .NET Framework 3.5 or later.
function Decrypt-KeyPlusIV ([byte[]] $Key, [byte[]] $IV, [byte[]] $CipherBytes)
{
    $Rijndael = New-Object -TypeName System.Security.Cryptography.RijndaelManaged
    $Rijndael.Key = $Key
    $Rijndael.IV = $IV 
    $Rijndael.Padding = [System.Security.Cryptography.PaddingMode]::ISO10126 
    $Decryptor = $Rijndael.CreateDecryptor()
    $MemoryStream = New-Object -TypeName System.IO.MemoryStream
    $StreamMode = [System.Security.Cryptography.CryptoStreamMode]::Write
    $CryptoStream = New-Object -TypeName System.Security.Cryptography.CryptoStream -ArgumentList $MemoryStream,$Decryptor,$StreamMode
    $CryptoStream.Write($CipherBytes, 0, $CipherBytes.Count) 
    $CryptoStream.Dispose() #Must come after the Write() or else "padding error" when decrypting.
    [byte[]] $MemoryStream.ToArray()
    $MemoryStream.Dispose()
}



# Construct and test path to encrypted password files.
$PasswordArchivePath = $(resolve-path -path $PasswordArchivePath).path
if ($PasswordArchivePath -notlike "*\") { $PasswordArchivePath = $PasswordArchivePath + "\" } 
if (-not $(test-path -path $PasswordArchivePath)) { "`nERROR: Cannot find path: " + $PasswordArchivePath + "`n" ; exit } 


# Get encrypted password files and sort by name, which sorts by tick number, i.e., by creation timestamp.
### Jason, replace the 'dir' to optimize when number of files is very large.
$files = @(dir ($PasswordArchivePath + "$ComputerName+*+*+*") | sort Name) 
if ($files.count -eq 0) { "`nERROR: No password archives for " + $ComputerName + "`n" ; exit } 


# Filter by UserName and get the latest archive file only, unless -ShowAll is used.
if (-not $ShowAll)
{ 
    $files = @( $files | where { $_.name -like "*+$($UserName.Trim())+*+*" } )
    if ($files.count -eq 0) { "`nERROR: No password archives for " + $ComputerName + "\" + $UserName + "`n" ; exit }  
    $files = $files[-1]
} 


# Load the current user's certificates and private keys.
try
{
    $readonlyflag = [System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly
    $currentuser =  [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    $usercertstore = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $currentuser
    $usercertstore.Open($readonlyflag) 
    $usercertificates = $usercertstore.Certificates
}
catch
{
    "`nERROR: Could not open your certificates store. `n"
    exit
}
finally
{
    $usercertstore.Close() 
}

if ($usercertificates.count -eq 0) { "`nERROR: You have no certificates or private keys.`n" ; exit }



# Process each encrypted password archive file.
foreach ($lastfile in $files) `
{
    $output = ($output = " " | select-object ComputerName,FilePath,UserName,TimeStamp,Thumbprint,Valid,StatusMessage,Password)

    $output.ComputerName = $($lastfile.Name -split '\+')[0]
    $output.FilePath =     $lastfile.fullname
    $output.UserName =     $($lastfile.Name -split '\+')[1]
    $output.TimeStamp =    [DateTime][Int64]$($lastfile.Name -split '\+')[2]
    $output.Valid =        $false  #Assume password recovery will fail.
    $output.Thumbprint =   $($lastfile.Name -split '\+')[3]


    # Check for password reset failure files.
    if ($output.Thumbprint -eq "PASSWORD-RESET-FAILURE") 
    { 
        $output.StatusMessage = "ERROR: Try to use prior password(s) for this computer."
        $output.Valid = $false
        $output
        continue 
    } 


    # Read in password archive binary file.
    [byte[]] $ciphertext = get-content -encoding byte -path $lastfile.fullname 
    if (-not $?) 
    { 
        $output.StatusMessage = "ERROR: Failed to read " + $lastfile.fullname
        $output.Valid = $false
        $output
        continue 
    }  


    # Sanity check size of archive file just read in (test with 1-char password and 1024-bit pub key).
    if ($ciphertext.count -lt 287) 
    { 
        $output.StatusMessage = "ERROR: Too small to be a valid file: " + $lastfile.fullname
        $output.Valid = $false
        $output
        continue 
    }  


    # Load the correct certificate and test for possession of private key.
    $thecert = $usercertificates | where { $_.thumbprint -eq $output.thumbprint } 
    if (-not $thecert.hasprivatekey) 
    { 
        $output.StatusMessage = "ERROR: You do not have the private key for this certificate."
        $output.Valid = $false
        $output
        continue
    } 


    # Test to confirm that the private key can be accessed, not just that it exists.  The
    # problem is that it is not a trivial task to allow .NET or PowerShell to use
    # private keys managed by Crytography Next Generation (CNG) key storage providers, hence,
    # these scripts are only compatible with the older Cryptographic Service Providers (CSPs), such
    # as the "Microsoft Enhanced Cryptographic Provider", but not the newer CNG "Microsoft
    # Software Key Storage Provider".  Sorry...
    if ($thecert.privatekey -eq $null) 
    { 
        $output.StatusMessage = "ERROR: This script is not compatible with CNG key storage providers."
        $output.Valid = $false
        $output
        continue
    } 


    # Size of the public key is needed to compute sizes of fields in the archive file.
    $pubkeysize = $thecert.publickey.key.keysize / 8   #Size in bytes.


    # Extract encrypted Key+IV from the ciphertext and decrypt them with private key.
    # If this raises a "Bad Key" error, then likely the certificate originally used to encrypt the data
    # does not have "Key Encipherment" listed under "Key Usage" in the properties of the cert.  The
    # cert template must include Encryption as an allowed purpose on the Request Handling tab.
    [byte[]] $KeyPlusIV = $thecert.privatekey.decrypt( [byte[]] @($ciphertext[0..$($pubkeysize - 1)]), $false)  #Must be $false for smart card to work.
    
    if (-not $? -or $KeyPlusIV.count -lt 48) 
    { 
        $output.StatusMessage = "ERROR: Decryption of symmetric key and IV failed, possibly because the certificate has a Key Usage which does not allow Key Encipherment.  Check the certificate template being used by your Certification Authority (CA): the template must have Encryption listed as an allowed purpose on the Request Handling tab in the properties of the template." 
        $output.Valid = $false
        $output
        continue 
    }
    

    # Remove Key+IV from $ciphertext to make offset calculations easier (can ignore pub key size now).
    $ciphertext = $ciphertext[$pubkeysize..($ciphertext.count - 1)] 


    # Decrypt the rest of the file with the Key and IV.
    [byte[]] $plaintextout = Decrypt-KeyPlusIV -Key $KeyPlusIV[0..31] -IV $KeyPlusIV[32..47] -CipherBytes $ciphertext
 
    if (-not $? -or $plaintextout.count -lt 152) #32-byte hash and 120-byte path at least. 
    { 
        $output.StatusMessage = "ERROR: Decryption of hash failed, possible archive file corruption." 
        $output.Valid = $false
        $output
        continue 
    }


    # Parse out the SHA256 hash, filename nonce, and password bytes (UTF16 = 2 bytes per char).
    [byte[]] $savedhash = $plaintextout[0..31]
    [byte[]] $savedpath = $plaintextout[32..151]
    [byte[]] $password =  $plaintextout[152..($plaintextout.Count - 1)] 
    

    # Convert password byte array back into UTF16LE.
    $output.Password = ([System.Text.Encoding]::Unicode).GetString($password) 
    if ($?) { $output.StatusMessage = "Success" } 


    # Confirm that the saved hash matches the current hash.
    $SHA256Hasher = [System.Security.Cryptography.SHA256]::Create()
    [Byte[]] $newhash = $SHA256Hasher.ComputeHash( $savedpath + $password ) 
    $SHA256Hasher = $null   #.Dispose() not supported in PowerShell 2.0


    if (compare-object -ReferenceObject $savedhash -DifferenceObject $newhash)
    { 
        $output.Valid = $false
        $output.StatusMessage = "ERROR: Hash integrity check failure, but password may still work."
        $output
        continue
    } 
    else
    { 
        #Compare-Object only produces output if there is a difference.
        $output.Valid = $true
    } 


    # Confirm that archive file name matches the path string in the file.
    # This string can also be used for troubleshooting if the files are renamed.
    $savedpathstring = ([System.Text.Encoding]::Unicode).GetString($savedpath)

    if ($lastfile.name -notlike ($savedpathstring + "*")) 
    { 
        $output.Valid = $false 
        $output.StatusMessage = "ERROR: Path check failure, but password may still work."
        $output
        continue 
    } 


    # Emit completed object, goto next archive file.
    $output
}



# FIN