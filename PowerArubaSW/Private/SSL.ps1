#
# Copyright 2018, Alexis La Goutte <alexis dot lagoutte at gmail dot com>
#
# SPDX-License-Identifier: Apache-2.0
#

# These helpers only run on Windows PowerShell (Desktop), where Invoke-WebRequest
# has no per-request -SkipCertificateCheck. On PowerShell Core (6/7) the per-request
# parameter is used instead (see Connect-ArubaSW), so the process-wide ServicePointManager
# state below is never touched there.
#
# Both Set-ArubaSWuntrustedSSL and Set-ArubaSWCipherSSL save the previous global value
# once, so Disconnect-ArubaSW can restore it via Restore-ArubaSWSSL and the trust bypass
# / protocol change does not leak into the rest of the PowerShell session.

Function Set-ArubaSWuntrustedSSL {

  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessforStateChangingFunctions", "")]
  [CmdletBinding()]
  Param(  )
  # Remember the original policy once, so Restore-ArubaSWSSL can put it back
  if (-not $script:ArubaSWCertificatePolicySaved) {
    $script:ArubaSWoldCertificatePolicy = [System.Net.ServicePointManager]::CertificatePolicy
    $script:ArubaSWCertificatePolicySaved = $true
  }

  # Hack for allowing untrusted SSL certs with https connections
  # (define the type only once per session)
  if (-not ('TrustAllCertsPolicy' -as [type])) {
    Add-Type -TypeDefinition @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
      public bool CheckValidationResult(
      ServicePoint srvPoint, X509Certificate certificate,
      WebRequest request, int certificateProblem) {
        return true;
      }
    }
"@
  }

  [System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy

}

Function Set-ArubaSWCipherSSL {

  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessforStateChangingFunctions", "")]
  [CmdletBinding()]
  Param(  )
  # Remember the original protocol set once, so Restore-ArubaSWSSL can put it back
  if (-not $script:ArubaSWSecurityProtocolSaved) {
    $script:ArubaSWoldSecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    $script:ArubaSWSecurityProtocolSaved = $true
  }

  # Enable TLS 1.2 (and TLS 1.3 where the runtime supports it). The deprecated
  # SSL3 / TLS 1.0 / TLS 1.1 protocols are intentionally NOT enabled anymore.
  $protocols = [System.Net.SecurityProtocolType]::Tls12
  if ([Enum]::GetNames([System.Net.SecurityProtocolType]) -contains 'Tls13') {
    $protocols = $protocols -bor [System.Net.SecurityProtocolType]'Tls13'
  }
  [System.Net.ServicePointManager]::SecurityProtocol = $protocols

}

Function Restore-ArubaSWSSL {

  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessforStateChangingFunctions", "")]
  [CmdletBinding()]
  Param(  )
  # Restore the process-wide certificate policy / security protocol that was changed
  # for a -SkipCertificateCheck connection on Desktop. No-op on Core (nothing saved).
  if ($script:ArubaSWCertificatePolicySaved) {
    [System.Net.ServicePointManager]::CertificatePolicy = $script:ArubaSWoldCertificatePolicy
    $script:ArubaSWoldCertificatePolicy = $null
    $script:ArubaSWCertificatePolicySaved = $false
  }
  if ($script:ArubaSWSecurityProtocolSaved) {
    [System.Net.ServicePointManager]::SecurityProtocol = $script:ArubaSWoldSecurityProtocol
    $script:ArubaSWSecurityProtocolSaved = $false
  }

}
