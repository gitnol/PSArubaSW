#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Optional credential store for Connect-ArubaSW (Increment I26): Windows Credential Manager, generic credentials, written and read
# in-process with CredWriteW/CredReadW. The password never appears on a process command
# line (unlike `cmdkey /pass:`) and is handed over as a BSTR pointer, so no managed
# plain-text string is created when writing; reading builds a SecureString directly from
# the native buffer. CRED_PERSIST_LOCAL_MACHINE: only for this user on this computer.
# Windows only; other platforms simply have no store (Get-... returns $null).

function Initialize-ArubaSWCredentialNative {

    <#
        .SYNOPSIS
        Compile the Win32 Credential Manager binding once per session (internal)

        .DESCRIPTION
        Own namespace `PowerArubaSW`, defined only once (Add-Type types cannot be unloaded).
        Write takes a pointer to a BSTR from the caller, Read returns the user name and a
        SecureString.

        .EXAMPLE
        Initialize-ArubaSWCredentialNative

        Make [PowerArubaSW.CredentialNative] available.
    #>

    [CmdletBinding()]
    Param()

    Process {
        if (([System.Management.Automation.PSTypeName]'PowerArubaSW.CredentialNative').Type) { return }
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security;
namespace PowerArubaSW {
public static class CredentialNative {
    public const uint CRED_TYPE_GENERIC          = 1;
    public const uint CRED_PERSIST_LOCAL_MACHINE = 2;
    public const int  CRED_MAX_CREDENTIAL_BLOB   = 5 * 512;
    const int ERROR_NOT_FOUND = 1168;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct CREDENTIAL_READ {
        public uint Flags; public uint Type; public IntPtr TargetName; public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize; public IntPtr CredentialBlob; public uint Persist;
        public uint AttributeCount; public IntPtr Attributes; public IntPtr TargetAlias; public IntPtr UserName;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct CREDENTIAL_WRITE {
        public uint Flags; public uint Type;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetName;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize; public IntPtr CredentialBlob; public uint Persist;
        public uint AttributeCount; public IntPtr Attributes;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetAlias;
        [MarshalAs(UnmanagedType.LPWStr)] public string UserName;
    }

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CredReadW")]
    static extern bool CredRead(string target, uint type, int reserved, out IntPtr credential);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CredWriteW")]
    static extern bool CredWrite(ref CREDENTIAL_WRITE credential, uint flags);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CredDeleteW")]
    static extern bool CredDelete(string target, uint type, int flags);

    [DllImport("advapi32.dll")]
    static extern void CredFree(IntPtr buffer);

    // Result: { UserName, SecureString, Persist } or null when the target does not exist.
    public static object[] Read(string target) {
        IntPtr p;
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out p)) return null;
        try {
            var c = (CREDENTIAL_READ)Marshal.PtrToStructure(p, typeof(CREDENTIAL_READ));
            var secure = new SecureString();
            int chars = (int)c.CredentialBlobSize / 2;
            for (int i = 0; i < chars; i++) secure.AppendChar((char)Marshal.ReadInt16(c.CredentialBlob, i * 2));
            secure.MakeReadOnly();
            return new object[] { Marshal.PtrToStringUni(c.UserName), secure, c.Persist };
        } finally { CredFree(p); }
    }

    // blob = pointer to the UTF-16 password (BSTR), blobBytes = length in bytes without terminator.
    public static void Write(string target, string userName, IntPtr blob, int blobBytes) {
        if (blobBytes > CRED_MAX_CREDENTIAL_BLOB)
            throw new ArgumentException("Password too long (max. " + (CRED_MAX_CREDENTIAL_BLOB / 2) + " characters).");
        var c = new CREDENTIAL_WRITE {
            Type               = CRED_TYPE_GENERIC,
            TargetName         = target,
            UserName           = userName,
            CredentialBlob     = blob,
            CredentialBlobSize = (uint)blobBytes,
            Persist            = CRED_PERSIST_LOCAL_MACHINE
        };
        if (!CredWrite(ref c, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
    }

    // true when deleted, false when the target did not exist.
    public static bool Delete(string target) {
        if (CredDelete(target, CRED_TYPE_GENERIC, 0)) return true;
        int err = Marshal.GetLastWin32Error();
        if (err == ERROR_NOT_FOUND) return false;
        throw new Win32Exception(err);
    }
}
}
'@
    }
}

function Test-ArubaSWCredentialStore {

    <#
        .SYNOPSIS
        Is the Windows Credential Manager available on this platform? (internal)

        .EXAMPLE
        Test-ArubaSWCredentialStore

        Returns $true on Windows, $false on Linux/macOS.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    Param()

    Process {
        [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    }
}

function Get-ArubaSWDefaultCredentialTarget {

    <#
        .SYNOPSIS
        Default Credential Manager target for a switch: PowerArubaSW_<server> (internal)

        .EXAMPLE
        Get-ArubaSWDefaultCredentialTarget -Server 192.0.2.1

        Returns PowerArubaSW_192.0.2.1
    #>

    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Server
    )

    Process {
        'PowerArubaSW_' + $Server.Trim()
    }
}

function Get-ArubaSWStoredCredential {

    <#
        .SYNOPSIS
        Read credentials from the Windows Credential Manager (internal)

        .DESCRIPTION
        Returns a PSCredential, or $null when the target does not exist, the platform has no
        Credential Manager, or the store cannot be read.

        .EXAMPLE
        Get-ArubaSWStoredCredential -Target PowerArubaSW_192.0.2.1

        Returns the stored PSCredential or $null.
    #>

    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Target
    )

    Process {
        if (-not (Test-ArubaSWCredentialStore)) { return $null }
        try {
            Initialize-ArubaSWCredentialNative
            $result = [PowerArubaSW.CredentialNative]::Read($Target)
            if (-not $result) { return $null }
            [System.Management.Automation.PSCredential]::new([string]$result[0], [System.Security.SecureString]$result[1])
        }
        catch {
            Write-Verbose "Credential store target '$Target' not readable: $_"
            $null
        }
    }
}

function Set-ArubaSWStoredCredential {

    <#
        .SYNOPSIS
        Write credentials to the Windows Credential Manager (internal)

        .DESCRIPTION
        Generic credential, CRED_PERSIST_LOCAL_MACHINE. An existing target is overwritten.
        The password is passed to CredWriteW as a BSTR pointer and zeroed afterwards.

        .EXAMPLE
        Set-ArubaSWStoredCredential -Target PowerArubaSW_192.0.2.1 -Credential $cred

        Store the credential.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Target,
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )

    Process {
        if (-not (Test-ArubaSWCredentialStore)) {
            throw "The credential store needs the Windows Credential Manager (not available on this platform)."
        }
        if ($PSCmdlet.ShouldProcess("Credential '$Target' (user '$($Credential.UserName)')", 'Store in Windows Credential Manager')) {
            Initialize-ArubaSWCredentialNative
            $password = $Credential.Password
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
            try {
                [PowerArubaSW.CredentialNative]::Write($Target, $Credential.UserName, $bstr, $password.Length * 2)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }
    }
}

function Remove-ArubaSWStoredCredential {

    <#
        .SYNOPSIS
        Delete credentials from the Windows Credential Manager (internal)

        .DESCRIPTION
        Returns $true when the target was deleted, $false when it did not exist.

        .EXAMPLE
        Remove-ArubaSWStoredCredential -Target PowerArubaSW_192.0.2.1

        Delete the stored credential.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Target
    )

    Process {
        if (-not (Test-ArubaSWCredentialStore)) {
            throw "The credential store needs the Windows Credential Manager (not available on this platform)."
        }
        if ($PSCmdlet.ShouldProcess("Credential '$Target'", 'Delete from Windows Credential Manager')) {
            Initialize-ArubaSWCredentialNative
            [PowerArubaSW.CredentialNative]::Delete($Target)
        }
    }
}

function Get-ArubaSWSecretCredential {

    <#
        .SYNOPSIS
        Read switch credentials from a SecretManagement vault (internal, optional)

        .DESCRIPTION
        Uses Get-Secret of the module Microsoft.PowerShell.SecretManagement (not a dependency of this module; only needed
        when -SecretName is used). The secret is a PSCredential, or a SecureString together with -Username.

        .EXAMPLE
        Get-ArubaSWSecretCredential -SecretName SwitchLab -Vault LabVault

        Returns the PSCredential stored as SwitchLab in the vault LabVault.
    #>

    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$SecretName,
        [Parameter(Mandatory = $false)]
        [string]$Vault,
        [Parameter(Mandatory = $false)]
        [string]$Username
    )

    Process {
        if (-not (Get-Command -Name Get-Secret -ErrorAction SilentlyContinue)) {
            throw "-SecretName needs the module Microsoft.PowerShell.SecretManagement (Get-Secret not found). Install it with Install-Module Microsoft.PowerShell.SecretManagement and register a vault."
        }
        $getParams = @{ Name = $SecretName; ErrorAction = 'Stop' }
        if ($Vault) {
            $getParams.Vault = $Vault
        }
        $secret = Get-Secret @getParams
        if ($null -eq $secret) {
            throw "Secret '$SecretName' not found in the SecretManagement vault."
        }
        if ($secret -is [System.Management.Automation.PSCredential]) {
            return $secret
        }
        if ($secret -is [SecureString]) {
            if (-not $Username) {
                throw "Secret '$SecretName' is a SecureString: pass -Username as well, or store a PSCredential."
            }
            return [System.Management.Automation.PSCredential]::new($Username, $secret)
        }
        throw "Secret '$SecretName' has the type $($secret.GetType().Name); expected PSCredential or SecureString (with -Username)."
    }
}

function Resolve-ArubaSWCredential {

    <#
        .SYNOPSIS
        Decide which credentials Connect-ArubaSW uses (internal)

        .DESCRIPTION
        Order: -Password (with -Username) -> -Credentials -> -CredentialTarget (Credential
        Manager, error when missing) -> -SecretName (SecretManagement vault, error when
        missing) -> default target PowerArubaSW_<server> (only when it exists) ->
        interactive Get-Credential prompt.

        .EXAMPLE
        Resolve-ArubaSWCredential -Server 192.0.2.1

        Returns the PSCredential to log in with.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "CredentialTarget", Justification = "CredentialTarget is the NAME of a Credential Manager entry, not a secret.")]
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Server,
        [Parameter(Mandatory = $false)]
        [string]$Username,
        [Parameter(Mandatory = $false)]
        [SecureString]$Password,
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credentials,
        [Parameter(Mandatory = $false)]
        [string]$CredentialTarget,
        [Parameter(Mandatory = $false)]
        [string]$SecretName,
        [Parameter(Mandatory = $false)]
        [string]$Vault
    )

    Process {
        if ($Password) {
            return [System.Management.Automation.PSCredential]::new($Username, $Password)
        }
        if ($null -ne $Credentials) {
            return $Credentials
        }
        if ($CredentialTarget) {
            if (-not (Test-ArubaSWCredentialStore)) {
                throw "-CredentialTarget needs the Windows Credential Manager (not available on this platform)."
            }
            $stored = Get-ArubaSWStoredCredential -Target $CredentialTarget
            if ($null -eq $stored) {
                throw "Credential target '$CredentialTarget' not found in the Windows Credential Manager. Create it with Save-ArubaSWCredential."
            }
            return $stored
        }
        if ($SecretName) {
            return Get-ArubaSWSecretCredential -SecretName $SecretName -Vault $Vault -Username $Username
        }
        if (Test-ArubaSWCredentialStore) {
            $defaultTarget = Get-ArubaSWDefaultCredentialTarget -Server $Server
            $stored = Get-ArubaSWStoredCredential -Target $defaultTarget
            if ($null -ne $stored) {
                Write-Verbose "Using stored credential '$defaultTarget'"
                return $stored
            }
        }
        Get-Credential -Message 'Please enter administrative credentials for your ArubaOS Switch'
    }
}
