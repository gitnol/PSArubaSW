#
# Copyright 2018, Alexis La Goutte <alexis dot lagoutte at gmail dot com>
#
# SPDX-License-Identifier: Apache-2.0
#

# Copy this file to credential.ps1 (on Tests folder) and change connection settings..
#
# Password (since I28), in this order:
#   1. Windows Credential Manager (recommended):  Save-ArubaSWCredential -Server <ipaddress>
#      (the user name of the stored entry is used)
#   2. environment variable ARUBASW_TEST_PASSWORD (CI, Linux/macOS), user name from $login below
#   3. $password below (plain text, only the fallback; this file is gitignored)

$script:ipaddress = "192.0.2.10"
$script:login = "admin"
# $script:password = "enable"   # fallback only, prefer the credential store (see above)
$script:httpOnly = $false


#default settings use for test, can be override if needed...

#$script:pester_vlan = 85
#$script:pester_vlanport = 8
#$script:pester_lacp_port = 5
#$script:pester_lacp_trk1 = "trk2"
#$script:pester_lacp_trk2 = "trk6"
#$script:pester_port = 3
#$script:pester_stack_module = 1
#$script:pester_chassis_module = "A"
#$script:pester_trunk_port = 5
#$script:pester_trunk_trk1 = "trk3"
#$script:pester_trunk_trk2 = "trk7"
#$script:pester_stp_port = 3
#$script:pester_cli_port = 3
#$script:pester_poe_port = 4
#$script:pester_dns1 = "1.1.1.1"
#$script:pester_dns2 = "8.8.8.8"