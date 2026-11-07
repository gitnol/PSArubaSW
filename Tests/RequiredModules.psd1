#
# Test-Abhängigkeiten für PowerArubaSW. Wird von .github/workflows/tests.yml
# (geplant in I6) und lokal beim Setup gelesen, um konsistente Pester-Versionen
# über alle Test-Läufe zu erzwingen.
#
# Installation lokal:
#   $req = Import-PowerShellDataFile .\Tests\RequiredModules.psd1
#   Install-Module Pester -RequiredVersion $req.Pester.RequiredVersion -Scope CurrentUser -Force -SkipPublisherCheck
#
@{
    Pester = @{
        # 5.5+ hat stabilen New-PesterConfiguration, Tag-Filter und CodeCoverage.
        # 5.7.1 ist die zum Inkrement I4 (2026-05-27) aktuelle Stable-Version.
        RequiredVersion = '5.7.1'
    }
    PSScriptAnalyzer = @{
        MinimumVersion = '1.21.0'
    }
}
