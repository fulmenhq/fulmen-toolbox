#!/usr/bin/env python3
"""Tests for release-verify.sh and image-digests.sh.

Throwaway PGP and minisign keys are committed as the release-key pin in a
disposable git repository holding a copy of the scripts; no network and no
real signing key are involved. Skipped when git, gpg or minisign is
unavailable, unless FULMEN_TOOLBOX_REQUIRE_CRYPTO_TOOLS=1, which makes a
missing tool a failure.
"""

import base64
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
TAG = "v1.2.3"
IMAGES = ("tools-a", "tools-b")
TOOLS = ("git", "gpg", "gpgconf", "minisign", "bash", "jq")


def clean_env():
    env = {
        k: v
        for k, v in os.environ.items()
        if not (
            k.startswith("FULMEN_TOOLBOX_") or k.startswith("GIT_") or k == "GNUPGHOME"
        )
    }
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    env["GIT_TERMINAL_PROMPT"] = "0"
    return env


def run(args, cwd=None, env=None, check=True, stdin=None):
    proc = subprocess.run(
        args,
        cwd=cwd,
        env=env or clean_env(),
        input=stdin,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if check and proc.returncode != 0:
        raise AssertionError(
            f"{' '.join(map(str, args))}: exit {proc.returncode}\n{proc.stdout}"
        )
    return proc.stdout, proc.returncode


class Signer:
    """A PGP primary with one signing and one encryption subkey, and a minisign key."""

    def __init__(self, root, name):
        # Short path: gpg-agent sockets live in the homedir (macOS ~104 bytes).
        self.home = tempfile.mkdtemp(prefix="rv-gpg-", dir="/tmp")
        os.chmod(self.home, 0o700)
        email = f"{name}@example.test"
        self.gpg("--quick-gen-key", f"{name} <{email}>", "ed25519", "cert", "never")
        self.primary = self.fprs(email)[0]
        self.gpg("--quick-add-key", self.primary, "ed25519", "sign", "never")
        self.gpg("--quick-add-key", self.primary, "cv25519", "encr", "never")
        self.primary, self.sign, self.encr = self.fprs(self.primary)
        self.full = Path(root) / f"{name}-full.asc"
        self.full.write_text(self.gpg("--armor", "--export", self.primary))
        # Primary + signing subkey only, as the toolbox release asset ships.
        self.short = Path(root) / f"{name}-short.asc"
        self.short.write_text(
            self.gpg(
                "--armor",
                "--export-options",
                "export-minimal",
                "--export",
                f"{self.sign}!",
                f"{self.primary}!",
            )
        )
        self.mini_key = Path(root) / f"{name}.key"
        self.mini_pub = Path(root) / f"{name}.pub"
        run(["minisign", "-G", "-W", "-p", self.mini_pub, "-s", self.mini_key])
        record = base64.b64decode(self.mini_pub.read_text().splitlines()[1])
        self.mini_sha = hashlib.sha256(record).hexdigest()

    def gpg(self, *args):
        out, _ = run(
            [
                "gpg",
                "--homedir",
                self.home,
                "--batch",
                "--pinentry-mode",
                "loopback",
                "--passphrase",
                "",
                *args,
            ]
        )
        return out

    def fprs(self, selector):
        out = self.gpg(
            "--with-colons", "--with-subkey-fingerprint", "--list-keys", selector
        )
        return [
            line.split(":")[9] for line in out.splitlines() if line.startswith("fpr:")
        ]

    def sign_manifest(self, manifest, image, version, subkey=None):
        Path(f"{manifest}.asc").unlink(missing_ok=True)
        self.gpg(
            "--local-user",
            f"{subkey or self.sign}!",
            "--detach-sign",
            "--armor",
            "-o",
            f"{manifest}.asc",
            manifest,
        )
        Path(f"{manifest}.minisig").unlink(missing_ok=True)
        run(
            [
                "minisign",
                "-S",
                "-W",
                "-s",
                self.mini_key,
                "-t",
                f"fulmen-toolbox {image} {version}",
                "-m",
                manifest,
            ]
        )

    def close(self):
        run(["gpgconf", "--homedir", self.home, "--kill", "all"], check=False)
        shutil.rmtree(self.home, ignore_errors=True)


class VerifyTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        missing = [t for t in TOOLS if not shutil.which(t)]
        if missing:
            if os.environ.get("FULMEN_TOOLBOX_REQUIRE_CRYPTO_TOOLS") == "1":
                raise AssertionError(f"required tools missing: {missing}")
            raise unittest.SkipTest(f"missing tools: {missing}")
        cls.keydir = tempfile.mkdtemp(prefix="rv-keys-")
        cls.real = Signer(cls.keydir, "release")
        cls.rogue = Signer(cls.keydir, "rogue")

    @classmethod
    def tearDownClass(cls):
        cls.real.close()
        cls.rogue.close()
        shutil.rmtree(cls.keydir, ignore_errors=True)

    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="rv-repo-"))
        self.addCleanup(shutil.rmtree, self.root, True)
        self.repo = self.root / "repo"
        (self.repo / "scripts").mkdir(parents=True)
        for name in ("release-verify.sh", "image-digests.sh"):
            shutil.copy(SCRIPTS / name, self.repo / "scripts" / name)
        self.commit_pin(self.real)
        self.dist = self.root / "dist"
        self.dist.mkdir()
        for image in IMAGES:
            m = self.dist / f"SHA256SUMS-{image}"
            m.write_text(f"sha256:{'a' * 64}  ghcr.io/example/{image}:{TAG}\n")
            self.real.sign_manifest(m, image, TAG[1:])
        shutil.copy(
            self.real.short, self.dist / "fulmen-toolbox-release-signing-key.asc"
        )
        shutil.copy(self.real.mini_pub, self.dist / "fulmenhq-release-signing.pub")

    def git(self, *args):
        env = clean_env()
        env.update(
            GIT_AUTHOR_NAME="t",
            GIT_AUTHOR_EMAIL="t@example.test",
            GIT_COMMITTER_NAME="t",
            GIT_COMMITTER_EMAIL="t@example.test",
        )
        return run(["git", "-C", self.repo, *args], env=env)[0]

    def commit_pin(self, signer, anchors=None, tag=TAG):
        (self.repo / "keys").mkdir(exist_ok=True)
        (self.repo / "docs" / "security").mkdir(parents=True, exist_ok=True)
        (self.repo / "keys" / "expected-fingerprints.txt").write_text(
            anchors
            if anchors is not None
            else f"gpg {signer.primary}\nminisign {signer.mini_sha}\n"
        )
        shutil.copy(
            signer.full, self.repo / "docs" / "security" / "release-signing-keys.asc"
        )
        shutil.copy(
            signer.mini_pub, self.repo / "docs" / "security" / "release-minisign.pub"
        )
        if not (self.repo / ".git").exists():
            self.git("init", "-q")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "pin", "--allow-empty")
        if tag:
            self.git("tag", "-f", tag)

    def verify(self, cmd="signatures", tag=TAG, **env):
        e = clean_env()
        e.update({f"FULMEN_TOOLBOX_{k}": str(v) for k, v in env.items()})
        return run(
            ["bash", self.repo / "scripts" / "release-verify.sh", cmd, tag, self.dist],
            env=e,
            check=False,
        )

    def assert_fails(self, want, **kw):
        out, rc = self.verify(**kw)
        self.assertNotEqual(rc, 0, out)
        self.assertIn(want, out)


class TestPinnedTrust(VerifyTestCase):
    def test_good_release_verifies_from_the_tag(self):
        out, rc = self.verify()
        self.assertEqual(rc, 0, out)
        self.assertIn("verified: 2 manifest(s)", out)
        self.assertIn("committed release-key pin at refs/tags/v1.2.3", out)

    def test_pin_command(self):
        out, rc = self.verify("pin")
        self.assertEqual(rc, 0, out)
        self.assertIn(self.real.sign, out)

    def test_keys_in_dir_are_not_trusted(self):
        # The attack the pin closes: swap both keys in the release directory
        # and re-sign every manifest with them.
        shutil.copy(
            self.rogue.short, self.dist / "fulmen-toolbox-release-signing-key.asc"
        )
        shutil.copy(self.rogue.mini_pub, self.dist / "fulmenhq-release-signing.pub")
        for image in IMAGES:
            self.rogue.sign_manifest(self.dist / f"SHA256SUMS-{image}", image, TAG[1:])
        self.assert_fails("is not the trusted minisign key")

    def test_rogue_signatures_without_key_assets(self):
        for name in (
            "fulmen-toolbox-release-signing-key.asc",
            "fulmenhq-release-signing.pub",
        ):
            (self.dist / name).unlink()
        image = IMAGES[0]
        self.rogue.sign_manifest(self.dist / f"SHA256SUMS-{image}", image, TAG[1:])
        self.assert_fails("PGP verification failed")

    def test_pgp_asset_with_foreign_key(self):
        both = self.dist / "fulmen-toolbox-release-signing-key.asc"
        both.write_text(self.real.short.read_text() + self.rogue.short.read_text())
        self.assert_fails("holds a key the trust does not")

    def test_pgp_asset_missing_signing_subkey(self):
        (self.dist / "fulmen-toolbox-release-signing-key.asc").write_text(
            self.real.gpg(
                "--armor",
                "--export-options",
                "export-minimal",
                "--export",
                f"{self.real.primary}!",
            )
        )
        self.assert_fails("does not hold the trusted key")

    def test_second_signing_subkey_is_refused(self):
        # A pin may hold only one signing subkey; a pinned key gaining a
        # second one is a pin change, not a new trusted signer.
        self.real.gpg("--quick-add-key", self.real.primary, "ed25519", "sign", "never")
        try:
            extra = Path(self.root) / "extra.asc"
            extra.write_text(self.real.gpg("--armor", "--export", self.real.primary))
            shutil.copy(
                extra, self.repo / "docs" / "security" / "release-signing-keys.asc"
            )
            self.git("add", "-A")
            self.git("commit", "-q", "-m", "two signing subkeys")
            self.git("tag", "-f", TAG)
            self.assert_fails("exactly one signing subkey")
        finally:
            newest = self.real.fprs(self.real.primary)[-1]
            self.real.gpg("--yes", "--delete-secret-and-public-key", f"{newest}!")

    def test_tampered_manifest(self):
        m = self.dist / f"SHA256SUMS-{IMAGES[0]}"
        m.write_text(m.read_text().replace("a" * 64, "b" * 64))
        self.assert_fails("PGP verification failed")

    def test_trusted_comment_names_the_tag(self):
        self.assert_fails("trusted comment", tag="v1.2.4", RELEASE_PIN_REF="HEAD")

    def test_missing_signature(self):
        (self.dist / f"SHA256SUMS-{IMAGES[1]}.minisig").unlink()
        self.assert_fails("missing")

    def test_orphan_signature(self):
        (self.dist / "SHA256SUMS-extra.asc").write_text("x")
        self.assert_fails("has no manifest")

    def test_tag_without_pin(self):
        self.git("tag", "-f", "v0.0.1", "HEAD")
        self.git("rm", "-q", "-r", "keys")
        self.git("commit", "-q", "-m", "drop pin")
        self.git("tag", "-f", "v0.0.1")
        self.assert_fails("is not committed in the pin ref", tag="v0.0.1")

    def test_missing_pin_ref(self):
        self.assert_fails("pin ref not found", RELEASE_PIN_REF="refs/tags/nope")

    def test_pin_ref_override(self):
        self.git("tag", "-d", TAG)
        out, rc = self.verify(RELEASE_PIN_REF="HEAD")
        self.assertEqual(rc, 0, out)

    def test_anchor_mismatch(self):
        self.commit_pin(
            self.real,
            anchors=f"gpg {self.rogue.primary}\nminisign {self.real.mini_sha}\n",
        )
        self.assert_fails("differs from its anchor")

    def test_minisign_anchor_mismatch(self):
        self.commit_pin(
            self.real,
            anchors=f"gpg {self.real.primary}\nminisign {self.rogue.mini_sha}\n",
        )
        self.assert_fails("pinned minisign key differs from its anchor")

    def test_malformed_anchors(self):
        self.commit_pin(self.real, anchors=f"gpg {self.real.primary}\n")
        self.assert_fails("must be exactly a gpg line then a minisign line")

    def test_working_tree_pin_is_ignored(self):
        # An uncommitted edit to the pin does not change what is trusted.
        shutil.copy(
            self.rogue.full,
            self.repo / "docs" / "security" / "release-signing-keys.asc",
        )
        out, rc = self.verify()
        self.assertEqual(rc, 0, out)


class TestEnvTrust(VerifyTestCase):
    def test_env_trust_outside_dir(self):
        out, rc = self.verify(
            RELEASE_TRUST="env",
            TRUST_PGP_KEYS=self.real.full,
            TRUST_MINISIGN_PUB=self.real.mini_pub,
        )
        self.assertEqual(rc, 0, out)
        self.assertIn("operator environment", out)

    def test_env_trust_inside_dir_is_refused(self):
        self.assert_fails(
            "must be outside",
            RELEASE_TRUST="env",
            TRUST_PGP_KEYS=self.dist / "fulmen-toolbox-release-signing-key.asc",
            TRUST_MINISIGN_PUB=self.real.mini_pub,
        )

    def test_env_trust_requires_both(self):
        self.assert_fails("needs", RELEASE_TRUST="env", TRUST_PGP_KEYS=self.real.full)

    def test_unknown_trust_mode(self):
        self.assert_fails("must be pin or env", RELEASE_TRUST="dir")


INDEX = {
    "mediaType": "application/vnd.oci.image.index.v1+json",
    "manifests": [
        {
            "digest": "sha256:" + "1" * 64,
            "platform": {"os": "linux", "architecture": "arm64"},
        },
        {
            "digest": "sha256:" + "2" * 64,
            "platform": {"os": "unknown", "architecture": "unknown"},
            "annotations": {"vnd.docker.reference.type": "attestation-manifest"},
        },
        {
            "digest": "sha256:" + "3" * 64,
            "platform": {"os": "linux", "architecture": "amd64"},
        },
    ],
}


class TestImageDigests(unittest.TestCase):
    def digests(self, doc, digest="sha256:" + "f" * 64):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(doc, f)
        self.addCleanup(os.unlink, f.name)
        return run(
            ["bash", SCRIPTS / "image-digests.sh", "--from-json", f.name, digest],
            check=False,
        )

    def test_index_and_platform_children_not_position(self):
        out, rc = self.digests(INDEX)
        self.assertEqual(rc, 0, out)
        self.assertEqual(
            out.splitlines(),
            [
                "index sha256:" + "f" * 64,
                "child sha256:" + "1" * 64 + " linux/arm64",
                "child sha256:" + "3" * 64 + " linux/amd64",
            ],
        )

    def test_single_platform_manifest_is_its_own_digest(self):
        out, rc = self.digests(
            {
                "mediaType": "application/vnd.oci.image.manifest.v1+json",
                "config": {"digest": "sha256:" + "9" * 64},
            }
        )
        self.assertEqual(rc, 0, out)
        self.assertEqual(out.splitlines(), ["index sha256:" + "f" * 64])

    def test_index_with_only_attestations_fails(self):
        doc = {"mediaType": INDEX["mediaType"], "manifests": [INDEX["manifests"][1]]}
        out, rc = self.digests(doc)
        self.assertNotEqual(rc, 0, out)
        self.assertIn("names no platform manifest", out)

    def test_duplicate_platform_fails(self):
        doc = dict(
            INDEX,
            manifests=INDEX["manifests"]
            + [
                {
                    "digest": "sha256:" + "4" * 64,
                    "platform": {"os": "linux", "architecture": "amd64"},
                }
            ],
        )
        out, rc = self.digests(doc)
        self.assertNotEqual(rc, 0, out)
        self.assertIn("more than one manifest", out)

    def test_invalid_digest_fails(self):
        out, rc = self.digests(INDEX, digest="sha256:xyz")
        self.assertNotEqual(rc, 0, out)


if __name__ == "__main__":
    unittest.main()
