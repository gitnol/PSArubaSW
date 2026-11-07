#!/usr/bin/env python3
"""
Validate a Recorded-Fixture (I10) against the corresponding response schema
in the OpenAPI spec (I11). Used as the engine for the Pester test
Tests/unit/FixturesAgainstSchema.Tests.ps1.

Exit codes:
    0  fixture validates
    1  fixture violates schema (prints up to 10 errors)
    2  fixture-meta cannot be resolved to a schema (lookup error)
"""
from __future__ import annotations
import argparse, json, re, sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator, RefResolver


def find_path(paths_dict: dict, uri: str) -> str | None:
    """Find the openapi path key that matches `uri` (with `{param}` substitution)."""
    target = "/" + uri.strip("/")
    if target in paths_dict:
        return target
    for path_key in paths_dict:
        pattern = "^" + re.sub(r"\{[^}]+\}", r"[^/]+", path_key) + "$"
        if re.match(pattern, target):
            return path_key
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--spec", required=True, help="Path to openapi.yaml")
    ap.add_argument("--fixture", required=True, help="Path to fixture .json")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    spec = yaml.safe_load(Path(args.spec).read_text(encoding="utf-8"))
    fixture = json.loads(Path(args.fixture).read_text(encoding="utf-8"))

    meta = fixture.get("meta", {})
    uri = str(meta.get("uri", "")).strip("/")
    method = str(meta.get("method", "")).lower()
    status = str(meta.get("status_code", ""))

    if not (uri and method and status):
        print(f"FAIL: fixture meta missing uri/method/status_code: {meta}")
        return 2

    # Error-Sample-Fixtures (z.B. generische 401/500 Bodies) tragen meta.uri="any"
    # und meta.method="any" — sie sind fuer Mock-Setups in Tests gedacht, nicht
    # fuer Vertrags-Validation gegen einen konkreten Endpoint. Sauber skippen.
    if uri.lower() == "any" or method.lower() == "any":
        print(f"SKIP: error-sample fixture (uri='{uri}', method='{method}') — not bound to a specific endpoint")
        return 0

    path_key = find_path(spec.get("paths", {}) or {}, uri)
    if not path_key:
        print(f"DRIFT: openapi.yaml has no path matching '{uri}' (method {method.upper()})")
        return 2

    op = spec["paths"][path_key].get(method)
    if not op:
        print(f"DRIFT: path {path_key} has no '{method}' operation in openapi.yaml")
        return 2

    responses = op.get("responses", {}) or {}
    resp = responses.get(status) or responses.get("default")
    if not resp:
        print(
            f"DRIFT: {method.upper()} {path_key} has no response entry for "
            f"status {status} in openapi.yaml (available: {list(responses)})"
        )
        return 2

    # Some operations legitimately have no body (204 No Content, simple DELETEs).
    content_block = resp.get("content") or {}
    schema = (content_block.get("application/json") or {}).get("schema")
    fix_body = fixture.get("content")
    if not schema:
        if not fix_body:
            print(f"OK: {method.upper()} {path_key} -> {status} (no body expected, no body present)")
            return 0
        print(
            f"DRIFT: {method.upper()} {path_key} -> {status} has no JSON response "
            f"schema in openapi.yaml, but fixture has a body"
        )
        return 2

    # Parse fixture.content (always a string in our fixture format).
    if isinstance(fix_body, str):
        try:
            data = json.loads(fix_body) if fix_body else None
        except json.JSONDecodeError as e:
            print(f"FAIL: fixture.content is not valid JSON: {e}")
            return 1
    else:
        data = fix_body

    # Resolve $refs against the full spec so #/components/schemas/X works.
    # We make the file path absolute and URL-escape spaces — RefResolver wants a URI.
    spec_uri = Path(args.spec).resolve().as_uri()
    resolver = RefResolver(base_uri=spec_uri, referrer=spec)
    validator = Draft202012Validator(schema, resolver=resolver)

    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
    if errors:
        print(
            f"FAIL: {len(errors)} schema violation(s) for "
            f"{method.upper()} {path_key} -> {status}"
        )
        for e in errors[:10]:
            loc = "/".join(str(p) for p in e.path) or "<root>"
            print(f"  - at {loc}: {e.message[:200]}")
        if args.verbose and len(errors) > 10:
            print(f"  ... ({len(errors) - 10} more)")
        return 1

    print(f"OK: {method.upper()} {path_key} -> {status} validated against schema")
    return 0


if __name__ == "__main__":
    sys.exit(main())
