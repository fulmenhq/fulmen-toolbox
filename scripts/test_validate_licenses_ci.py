#!/usr/bin/env python3
"""Guard the license-validation CI split and fail-closed cache key.

Fails if validate-licenses is folded back into the schema job, if the
cache key drops the input hashes that determine the result, or if a
cache miss / restore error can skip the full check.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github/workflows/validate-manifest.yml"

JOB_ID = "validate-licenses"
CACHE_SCHEMA = "license-validation-v1-"
REQUIRED_HASH_NEEDLES = (
    "manifests/tools.json",
    "scripts/validate-licenses.sh",
    "images/",
    "Makefile",
)

# Snapshot of the pre-split layout: licenses ran as a step inside `validate`,
# after APK/profile checks and before the PR docker build. Used to prove this
# test fails if that layout is restored.
REVERTED_WORKFLOW = """
name: Validate Toolbox Manifests
on:
  pull_request:
    paths:
      - "manifests/**"
jobs:
  validate:
    runs-on: ubuntu-latest-x64-m
    steps:
      - uses: actions/checkout@v4
      - name: Validate curated licenses
        run: make validate-licenses
      - name: "Optional: quick docker build (PR confidence)"
        if: "github.event_name == 'pull_request'"
        uses: docker/build-push-action@v6
"""


def parse_gha_jobs(text):
    """Return {job_id: body} for top-level jobs in a GitHub Actions workflow."""
    jobs = {}
    in_jobs = False
    current = None
    buf = []
    for line in text.splitlines(keepends=True):
        if not in_jobs:
            if re.match(r"^jobs:\s*(#.*)?$", line):
                in_jobs = True
            continue
        job_header = re.match(r"^  ([A-Za-z0-9_-]+):\s*(#.*)?$", line)
        if job_header:
            if current is not None:
                jobs[current] = "".join(buf)
            current = job_header.group(1)
            buf = [line]
            continue
        if re.match(r"^[^\s#]", line):
            break
        if current is not None:
            buf.append(line)
    if current is not None:
        jobs[current] = "".join(buf)
    return jobs


def _job_has_needs(body):
    return re.search(r"(?m)^    needs:", body) is not None


def license_ci_contract_errors(text):
    """Return a list of contract violations for the license-check workflow."""
    errors = []
    jobs = parse_gha_jobs(text)
    if JOB_ID not in jobs:
        errors.append(f"missing dedicated job {JOB_ID!r}")
        return errors

    body = jobs[JOB_ID]
    if _job_has_needs(body):
        errors.append(f"{JOB_ID} must not set needs: (must run in parallel)")

    if "actions/cache" not in body:
        errors.append(f"{JOB_ID} must use actions/cache")
    if "hashFiles(" not in body:
        errors.append("cache key must use hashFiles(...)")
    if CACHE_SCHEMA not in body:
        errors.append(f"cache key must include schema version prefix {CACHE_SCHEMA!r}")
    for needle in REQUIRED_HASH_NEEDLES:
        if needle not in body:
            errors.append(f"cache key must include input {needle!r}")

    if "make validate-licenses" not in body:
        errors.append(f"{JOB_ID} must run make validate-licenses")
    if "continue-on-error: true" not in body:
        errors.append("cache restore must continue-on-error so a miss/error still runs the check")
    if ".cache/license-validation" not in body:
        errors.append("cached result path .cache/license-validation is required")
    if not re.search(r"\[ -f .*RESULT_FILE|\[ -f .*result", body):
        errors.append("skip path must verify the cached result file exists")
    if not re.search(r'got.*=.*"ok"|grep -qx ok', body):
        errors.append("skip path must verify the cached result content is ok")
    if "cache_used" not in body and "cache-hit" not in body:
        errors.append("must branch on cache hit vs miss")
    if "success()" not in body:
        errors.append("cache save must be gated on success() so a failed check is never cached")

    validate_body = jobs.get("validate", "")
    if "make validate-licenses" in validate_body:
        errors.append("make validate-licenses must not remain in the validate job")
    if "make test-validate-licenses-ci" not in validate_body:
        errors.append("validate job must run make test-validate-licenses-ci")

    other_jobs = [name for name in jobs if name != JOB_ID]
    if not other_jobs:
        errors.append(f"{JOB_ID} must run in parallel with at least one other job")
    for name in other_jobs:
        if re.search(rf"(?m)^    needs:.*{re.escape(JOB_ID)}", jobs[name]):
            errors.append(f"{name} must not need: {JOB_ID}")

    return errors


class TestValidateLicensesCI(unittest.TestCase):
    def test_live_workflow_satisfies_contract(self):
        text = WORKFLOW.read_text(encoding="utf-8")
        errors = license_ci_contract_errors(text)
        self.assertEqual(errors, [], msg="; ".join(errors))

    def test_reverted_inline_job_fails_contract(self):
        errors = license_ci_contract_errors(REVERTED_WORKFLOW)
        self.assertTrue(errors, "reverted inline license step must fail this test")
        self.assertTrue(
            any("dedicated job" in e for e in errors),
            f"expected missing-job error, got {errors!r}",
        )

    def test_cache_key_without_tools_json_hash_fails(self):
        text = WORKFLOW.read_text(encoding="utf-8")
        mutated = text.replace("'manifests/tools.json', ", "")
        self.assertNotEqual(mutated, text, "fixture must drop tools.json from the cache key")
        errors = license_ci_contract_errors(mutated)
        self.assertTrue(
            any("manifests/tools.json" in e for e in errors),
            f"expected tools.json cache-key error, got {errors!r}",
        )

    def test_cache_key_without_hashfiles_fails(self):
        text = WORKFLOW.read_text(encoding="utf-8")
        mutated = text.replace("hashFiles(", "identity(")
        errors = license_ci_contract_errors(mutated)
        self.assertTrue(
            any("hashFiles" in e for e in errors),
            f"expected hashFiles error, got {errors!r}",
        )

    def test_needs_gating_fails_contract(self):
        text = WORKFLOW.read_text(encoding="utf-8")
        mutated = text.replace(
            "  validate-licenses:\n    runs-on: ubuntu-latest-x64-m\n",
            "  validate-licenses:\n    needs: [docker-build]\n    runs-on: ubuntu-latest-x64-m\n",
        )
        self.assertNotEqual(mutated, text)
        errors = license_ci_contract_errors(mutated)
        self.assertTrue(
            any("needs:" in e for e in errors),
            f"expected needs: gating error, got {errors!r}",
        )

    def test_skip_without_result_file_check_fails(self):
        text = WORKFLOW.read_text(encoding="utf-8")
        mutated = text.replace("[ -f \"$RESULT_FILE\" ]", "[ 1 = 1 ]")
        self.assertNotEqual(mutated, text)
        errors = license_ci_contract_errors(mutated)
        self.assertTrue(
            any("result file" in e for e in errors),
            f"expected result-file check error, got {errors!r}",
        )


if __name__ == "__main__":
    unittest.main()
