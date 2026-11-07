# Recorded Fixtures — PowerArubaSW

Realistische API-Antworten des ArubaOS-Switches, aufgenommen oder hand-erstellt,
**vollständig anonymisiert**, eingecheckt. Werden von Unit-Tests via
`Tests/unit/_helpers/Get-Fixture.ps1` geladen, sodass Pester-Mocks gegen echtes
Antwort-Format prüfen statt gegen konstruierte Inline-Stubs.

Eingeführt in **Inkrement I10**; inspiriert von
VCR (Ruby), vcrpy (Python), Polly.js (JS), HttpClientInterception (.NET).

---

## Layout

```
Tests/fixtures/
├── README.md                                  ← du bist hier
├── v3/                                        ← REST-API-Version (Login fix auf v3)
│   └── login-sessions/
│       └── post-success.json
└── v8/                                        ← REST-API-Version (Standard-Calls)
    ├── vlans/
    │   ├── get-default.json                   ← scenario name = file name (ohne .json)
    │   ├── post-add.json
    │   └── put-set.json
    ├── port/
    │   └── get-default.json
    ├── system/
    │   └── get-default.json
    ├── system-status-switch/
    │   └── get-default.json
    └── errors/
        ├── 401-unauthorized.json
        └── 500-internal.json
```

Pfad-Konvention: `Tests/fixtures/v<api>/<resource>/<scenario>.json`.

---

## Datei-Format

```json
{
  "meta": {
    "uri": "vlans",
    "method": "GET",
    "api_version": 8,
    "status_code": 200,
    "recorded_at": "2026-05-27",
    "firmware": "ANONYMIZED",
    "switch_model": "ANONYMIZED",
    "anonymized": true,
    "note": "Optional: Kontext, Stand, Hand-crafted vs. Recorded"
  },
  "content": "{\"vlan_element\":[ ... als String, exakt wie der Switch ihn als Response-Body liefert ... ]}"
}
```

`content` ist ein **String** (kein JSON-Sub-Objekt), weil die echte Response von
`Invoke-WebRequest` ebenfalls `.Content` als String trägt. Damit ist der
Fixture-Loader drop-in-Replacement für das Mock-Return.

---

## Benutzung im Test

```powershell
. "$PSScriptRoot\_helpers\Get-Fixture.ps1"   # in BeforeAll

Describe 'Get-ArubaSWVlans' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource vlans -Name get-default
        }
    }
    It 'parst die VLAN-Liste' {
        $r = Get-ArubaSWVlans -connection $StubConnection
        $r.Count | Should -Be 3
        $r[0].name | Should -Be 'DEFAULT_VLAN'
    }
}
```

Get-Fixture liefert ein PSObject `@{ StatusCode; Content; _meta }`, das
exakt dem entspricht, was `Invoke-WebRequest`/`Invoke-ArubaSWWebRequest`
zurückgibt — `Resource`-Cmdlets können es ohne Umbauen verarbeiten.

---

## Neue Fixture aufnehmen

### Aus echter Hardware (empfohlen für Schema-Fidelität)

```powershell
# 1. Verbinden
Connect-ArubaSW -Server <ip> -SkipCertificateCheck

# 2. Aufnehmen
.\Tools\Save-ArubaSWFixture.ps1 -Resource vlans -Name get-default `
    -Method GET -Uri vlans

# 3. Anonymisieren BEFORE COMMIT
.\Tools\Anonymize-Fixture.ps1 -Path Tests\fixtures\v8\vlans\get-default.json

# 4. Manuell prüfen (siehe Abschnitt unten); ggf. weitere Replacements:
.\Tools\Anonymize-Fixture.ps1 -Path Tests\fixtures\v8\radius-server\get-default.json `
    -AdditionalReplacements @{
        '"shared_secret"\s*:\s*"[^"]+"' = '"shared_secret":"ANONYMIZED-SHARED-SECRET"'
    }

# 5. Disconnect
Disconnect-ArubaSW
```

### Hand-gefertigt (wenn keine Hardware verfügbar)

JSON-Datei nach obigem Schema direkt anlegen. `meta.note` einen Hinweis
„Hand-crafted starter fixture (no real switch recording yet)" eintragen,
damit klar ist, dass Felder evtl. unvollständig sind.

---

## Anonymisierungs-Pflicht (KRITISCH)

`Tools/Anonymize-Fixture.ps1` scrubt automatisch:
- IPv4-Adressen → `198.51.100.1` (RFC 5737 TEST-NET-2)
- MAC-Adressen (colon-/dash-/dot-separated) → `00:00:5E:00:53:00`
  (IANA Documentation Range)

**Was du manuell prüfen MUSST** (per `-AdditionalReplacements`):
- **RADIUS Shared Secrets** — sonst stehen Auth-Geheimnisse im Repo
- **SNMP Communities** — Read/Write-Communities sind Credentials
- **Seriennummern** (Switch, Module) — können Asset-Tracking erlauben
- **Hostnames** mit Firmen-Domains (`switch01.corp.example.com`)
- **Custom Location/Contact-Felder** in `system.location` / `system.contact`
- **Session-Cookies** in `login-sessions`-Responses (selbst wenn der Switch sie
  schon invalidiert hat — Format gibt Layout preis)

Faustregel: alles, was einen **echten** Wert (vs. einen Test-Wert wie
`PowerArubaSW`) hat, ist Kandidat für Anonymisierung. **Im Zweifel scrubben.**

---

## Refresh-Workflow

Wenn der Switch eine neue Firmware bekommt oder die REST-API-Antwort sich ändert:

1. Fixture aus `Tests/fixtures/` löschen oder mit `Save-ArubaSWFixture -Force` überschreiben.
2. `meta.firmware` + `meta.switch_model` aktualisieren (manuell, nach Anonymisierung).
3. Tests laufen lassen — wenn jetzt rot, ist's echte Schema-Drift und muss adressiert werden.

Empfohlener Rhythmus: bei jedem Switch-Firmware-Upgrade des Lab-Switches, oder
quartärlich, je nachdem was häufiger ist.

---

## Verweise

