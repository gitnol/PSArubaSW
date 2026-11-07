# Optionaler Schema-Test (OpenAPI)

Der Test `Tests/unit/FixturesAgainstSchema.Tests.ps1` prüft jede Fixture in `Tests/fixtures/` gegen ein
OpenAPI-Schema. Dieses Schema (`Tests/schema/openapi.yaml`) liegt **nicht** im Repository, weil es aus
urheberrechtlich geschützten HPE/Aruba-Dokumenten abgeleitet wird. Fehlt die Datei, werden die Schema-Tests
übersprungen; alle anderen Tests laufen unverändert.

## So entsteht die Datei

1. Die Referenzdokumente selbst von HPE/Aruba herunterladen (Support-Portal, "ArubaOS-Switch REST API and JSON Schema
   Reference Guide", z. B. Version 16.04, sowie die Update-Guides 16.09 bis 16.11). Die PDFs nicht einchecken
   (`.gitignore` schließt `HPE_*.pdf` und `Aruba REST API*.pdf` aus).
2. Aus dem Referenzhandbuch ein OpenAPI 3.0.3 Dokument erzeugen. Je Pfad (z. B. `/vlans`) und Methode (GET, POST, PUT,
   DELETE) wird die Response-Struktur als JSON-Schema beschrieben. Das lässt sich von Hand, mit einem Skript oder mit
   Hilfe eines KI-Assistenten machen. Die Änderungen aus den späteren Update-Guides danach nachtragen.
3. Die Datei als `Tests/schema/openapi.yaml` speichern.
4. Voraussetzung: Python 3 mit den Paketen `pyyaml` und `jsonschema` (`python -m pip install pyyaml jsonschema`).
5. Tests laufen lassen, z. B. `Invoke-Pester Tests/unit/FixturesAgainstSchema.Tests.ps1`. Jede Fixture, die nicht zum
   Schema passt, meldet einen Fehler (`Tools/Validate-Fixture.py` ist die Prüfmaschine).

Die erzeugte Datei bleibt lokal (steht in `.gitignore`).
