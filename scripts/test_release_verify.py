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
        for name in (
            "release-verify.sh",
            "image-digests.sh",
            "release-sign.sh",
            "cosign-release.sh",
        ):
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
            self.signed_tag(tag, signer)

    def signed_tag(self, tag, signer, subkey=None, ref="HEAD"):
        """An annotated tag signed by the signer's signing subkey."""
        env = clean_env()
        env.update(
            GNUPGHOME=signer.home,
            GIT_AUTHOR_NAME="t",
            GIT_AUTHOR_EMAIL="t@example.test",
            GIT_COMMITTER_NAME="t",
            GIT_COMMITTER_EMAIL="t@example.test",
        )
        run(
            [
                "git",
                "-C",
                self.repo,
                "-c",
                "gpg.program=gpg",
                "tag",
                "-f",
                "-s",
                "-u",
                f"{subkey or signer.sign}!",
                "-m",
                tag,
                tag,
                ref,
            ],
            env=env,
        )

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
        self.assertIn(f"tag signed by {self.real.sign}", out)

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
            self.signed_tag(TAG, self.real)
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
        self.git("rm", "-q", "-r", "keys")
        self.git("commit", "-q", "-m", "drop pin")
        self.signed_tag("v0.0.1", self.real)
        self.assert_fails("is not committed in the pin ref", tag="v0.0.1")

    def test_lightweight_tag_is_refused(self):
        self.git("tag", "-d", TAG)
        self.git("tag", TAG)
        self.assert_fails("is not an annotated tag")

    def test_unsigned_annotated_tag_is_refused(self):
        self.git("tag", "-d", TAG)
        self.git("tag", "-a", "-m", TAG, TAG)
        self.assert_fails("does not verify with the pinned keys")

    def test_tag_signed_by_another_key_is_refused(self):
        self.signed_tag(TAG, self.rogue)
        self.assert_fails("does not verify with the pinned keys")

    def test_tag_object_for_another_name_is_refused(self):
        self.signed_tag("v9.9.9", self.real)
        self.git("tag", "-d", TAG)
        tag_obj = self.git("rev-parse", "refs/tags/v9.9.9").strip()
        self.git("update-ref", f"refs/tags/{TAG}", tag_obj)
        self.assert_fails("records a different tag name")

    def test_pin_ref_override_skips_tag_signature(self):
        out, rc = self.verify(RELEASE_PIN_REF="HEAD")
        self.assertEqual(rc, 0, out)
        self.assertIn("tag signature not checked", out)

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


class TestReleaseSign(VerifyTestCase):
    """release-sign.sh refuses operator keys that are not the pin, before
    touching any existing signature, and only promotes verified signatures."""

    def sign(self, gpg_home, key_id, mini_key):
        e = clean_env()
        e.update(
            FULMEN_TOOLBOX_IMAGES=" ".join(IMAGES),
            FULMEN_TOOLBOX_GPG_HOMEDIR=gpg_home,
            FULMEN_TOOLBOX_PGP_KEY_ID=key_id,
            FULMEN_TOOLBOX_MINISIGN_KEY=str(mini_key),
        )
        return run(
            ["bash", self.repo / "scripts" / "release-sign.sh", TAG, self.dist],
            env=e,
            check=False,
        )

    def snapshot(self):
        return {p.name: p.read_bytes() for p in sorted(self.dist.iterdir())}

    def test_pinned_keys_sign_and_verify(self):
        for image in IMAGES:
            for ext in ("asc", "minisig"):
                (self.dist / f"SHA256SUMS-{image}.{ext}").unlink()
        out, rc = self.sign(self.real.home, f"{self.real.sign}!", self.real.mini_key)
        self.assertEqual(rc, 0, out)
        self.assertIn("Release signing complete", out)
        out, rc = self.verify()
        self.assertEqual(rc, 0, out)

    def test_primary_selector_signs_with_pinned_subkey(self):
        out, rc = self.sign(self.real.home, self.real.primary, self.real.mini_key)
        self.assertEqual(rc, 0, out)

    def test_rogue_pgp_key_changes_nothing(self):
        before = self.snapshot()
        out, rc = self.sign(self.rogue.home, f"{self.rogue.sign}!", self.real.mini_key)
        self.assertNotEqual(rc, 0, out)
        self.assertIn("not the pinned primary", out)
        self.assertEqual(self.snapshot(), before)

    def test_rogue_minisign_key_changes_nothing(self):
        before = self.snapshot()
        out, rc = self.sign(self.real.home, f"{self.real.sign}!", self.rogue.mini_key)
        self.assertNotEqual(rc, 0, out)
        self.assertIn("not the pinned minisign key", out)
        self.assertEqual(self.snapshot(), before)

    def test_env_trust_override_does_not_decide_promotion(self):
        # A rogue minisign secret with the pinned public key beside it passes
        # the preflight; an inherited env trust override that matches the
        # rogue key must not let the staged result be promoted.
        pair = Path(self.root) / "pair"
        pair.mkdir()
        shutil.copy(self.rogue.mini_key, pair / "minisign.key")
        shutil.copy(self.real.mini_pub, pair / "minisign.pub")
        before = self.snapshot()
        e = clean_env()
        e.update(
            FULMEN_TOOLBOX_IMAGES=" ".join(IMAGES),
            FULMEN_TOOLBOX_GPG_HOMEDIR=self.real.home,
            FULMEN_TOOLBOX_PGP_KEY_ID=f"{self.real.sign}!",
            FULMEN_TOOLBOX_MINISIGN_KEY=str(pair / "minisign.key"),
            FULMEN_TOOLBOX_RELEASE_TRUST="env",
            FULMEN_TOOLBOX_TRUST_PGP_KEYS=str(self.real.full),
            FULMEN_TOOLBOX_TRUST_MINISIGN_PUB=str(self.rogue.mini_pub),
        )
        out, rc = run(
            ["bash", self.repo / "scripts" / "release-sign.sh", TAG, self.dist],
            env=e,
            check=False,
        )
        self.assertNotEqual(rc, 0, out)
        self.assertIn("do not verify against the pin", out)
        self.assertEqual(self.snapshot(), before)

    def test_other_subkey_selector_changes_nothing(self):
        before = self.snapshot()
        out, rc = self.sign(self.real.home, f"{self.real.encr}!", self.real.mini_key)
        self.assertNotEqual(rc, 0, out)
        self.assertIn("is not the pinned signing subkey", out)
        self.assertEqual(self.snapshot(), before)


COSIGN_STUB = """#!/usr/bin/env bash
echo "$*" >> "$COSIGN_LOG"
"""

# The live registry view: STUB_LIVE for every name, or STUB_ODD_LIVE for
# the name in STUB_ODD_NAME.
DIGESTS_STUB = """#!/usr/bin/env bash
case "$1" in
*/$STUB_ODD_NAME:*) printf '%s\\n' "$STUB_ODD_LIVE" ;;
*) printf '%s\\n' "$STUB_LIVE" ;;
esac
"""


class TestCosignRelease(unittest.TestCase):
    """cosign-release.sh covers every published name x (index + each child);
    each child is attested with its own SBOM; the index is never attested."""

    INDEX = "sha256:" + "f" * 64
    ARM = "sha256:" + "1" * 64
    AMD = "sha256:" + "3" * 64

    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="rv-cosign-"))
        self.addCleanup(shutil.rmtree, self.root, True)
        self.log = self.root / "cosign.log"
        for name, body in (("cosign", COSIGN_STUB), ("digests", DIGESTS_STUB)):
            (self.root / name).write_text(body)
            (self.root / name).chmod(0o755)
        self.digests = self.root / "DIGESTS-img"
        self.digests.write_text(
            f"index {self.INDEX}\nchild {self.ARM} linux/arm64\nchild {self.AMD} linux/amd64\n"
        )
        self.sboms = self.root / "sboms"
        self.sboms.mkdir()
        for arch in ("arm64", "amd64"):
            (self.sboms / f"sbom-img-1.2.3-linux-{arch}.json").write_text(arch)

    def live(self, *children):
        return "\n".join(
            [f"index {self.INDEX}"] + [f"child {d} {p}" for d, p in children]
        )

    def cosign(self, cmd, *aliases, odd="", odd_live=""):
        e = clean_env()
        e.update(
            COSIGN=str(self.root / "cosign"),
            IMAGE_DIGESTS=str(self.root / "digests"),
            COSIGN_LOG=str(self.log),
            STUB_LIVE=self.live((self.ARM, "linux/arm64"), (self.AMD, "linux/amd64")),
            STUB_ODD_NAME=odd or "none",
            STUB_ODD_LIVE=odd_live,
            REGISTRY="reg",
            OWNER="own",
            CERT_IDENTITY="id",
            CERT_ISSUER="iss",
        )
        args = [
            "bash",
            SCRIPTS / "cosign-release.sh",
            cmd,
            "img",
            "1.2.3",
            self.digests,
            self.sboms,
            *aliases,
        ]
        out, rc = run(args, env=e, check=False)
        calls = self.log.read_text().splitlines() if self.log.exists() else []
        return out, rc, calls

    def test_sign_covers_every_name_and_digest(self):
        out, rc, calls = self.cosign("sign", "alias-a", "alias-b")
        self.assertEqual(rc, 0, out)
        for name in ("img", "alias-a", "alias-b"):
            ref = f"reg/own/{name}"
            self.assertIn(f"sign {ref}@{self.INDEX}", calls)
            self.assertIn(f"sign {ref}@{self.ARM}", calls)
            self.assertIn(f"sign {ref}@{self.AMD}", calls)
            self.assertIn(
                f"attest --predicate {self.sboms}/sbom-img-1.2.3-linux-arm64.json --type spdxjson {ref}@{self.ARM}",
                calls,
            )
            self.assertIn(
                f"attest --predicate {self.sboms}/sbom-img-1.2.3-linux-amd64.json --type spdxjson {ref}@{self.AMD}",
                calls,
            )
            self.assertFalse(
                any(
                    c.startswith("attest") and c.endswith(f"{ref}@{self.INDEX}")
                    for c in calls
                )
            )
        self.assertEqual(len(calls), 3 * 5)

    def test_verify_covers_every_name_and_digest(self):
        out, rc, calls = self.cosign("verify", "alias-a")
        self.assertEqual(rc, 0, out)
        for name in ("img", "alias-a"):
            ref = f"reg/own/{name}"
            for d in (self.INDEX, self.ARM, self.AMD):
                self.assertIn(
                    f"verify --certificate-identity id --certificate-oidc-issuer iss {ref}@{d}",
                    calls,
                )
            for d in (self.ARM, self.AMD):
                self.assertIn(
                    f"verify-attestation --type spdxjson --certificate-identity id --certificate-oidc-issuer iss {ref}@{d}",
                    calls,
                )
            self.assertFalse(
                any(
                    c.startswith("verify-attestation")
                    and c.endswith(f"{ref}@{self.INDEX}")
                    for c in calls
                )
            )

    def assert_mismatch(self, cmd="verify", odd="", odd_live=""):
        out, rc, calls = self.cosign(cmd, "alias-a", odd=odd, odd_live=odd_live)
        self.assertNotEqual(rc, 0, out)
        self.assertEqual(calls, [], "no cosign call before the inventory check")
        return out

    def test_alias_on_another_index_fails(self):
        other = "sha256:" + "e" * 64
        out = self.assert_mismatch(
            odd="alias-a",
            odd_live=f"index {other}\nchild {self.ARM} linux/arm64\nchild {self.AMD} linux/amd64",
        )
        self.assertIn("alias-a:v1.2.3 does not match", out)

    def test_digests_file_omitting_a_child_fails(self):
        self.digests.write_text(f"index {self.INDEX}\nchild {self.ARM} linux/arm64\n")
        for cmd in ("sign", "verify"):
            self.assertIn("img:v1.2.3 does not match", self.assert_mismatch(cmd))

    def test_digests_file_adding_a_child_fails(self):
        extra = "sha256:" + "5" * 64
        self.digests.write_text(
            self.digests.read_text() + f"child {extra} linux/s390x\n"
        )
        (self.sboms / "sbom-img-1.2.3-linux-s390x.json").write_text("s390x")
        self.assertIn("does not match", self.assert_mismatch("sign"))

    def test_digests_file_substituting_a_child_fails(self):
        other = "sha256:" + "6" * 64
        self.digests.write_text(self.digests.read_text().replace(self.AMD, other))
        self.assertIn("does not match", self.assert_mismatch("sign"))

    def test_digests_file_repeating_an_entry_fails(self):
        self.digests.write_text(
            self.digests.read_text() + f"child {self.AMD} linux/amd64\n"
        )
        self.assertIn("repeats an entry", self.assert_mismatch("sign"))

    def test_one_name_missing_a_child_fails(self):
        out = self.assert_mismatch(
            odd="alias-a", odd_live=f"index {self.INDEX}\nchild {self.ARM} linux/arm64"
        )
        self.assertIn("alias-a:v1.2.3 does not match", out)

    def test_missing_child_sbom_fails_before_signing(self):
        (self.sboms / "sbom-img-1.2.3-linux-amd64.json").unlink()
        out, rc, calls = self.cosign("sign")
        self.assertNotEqual(rc, 0, out)
        self.assertIn("missing SBOM for linux/amd64", out)
        self.assertEqual(calls, [])

    def test_digests_file_without_children_fails(self):
        self.digests.write_text(f"index {self.INDEX}\n")
        out, rc, calls = self.cosign("sign")
        self.assertNotEqual(rc, 0, out)
        self.assertEqual(calls, [])

    def test_verify_needs_identity(self):
        e = clean_env()
        e.update(COSIGN=str(self.root / "cosign"), COSIGN_LOG=str(self.log))
        out, rc = run(
            [
                "bash",
                SCRIPTS / "cosign-release.sh",
                "verify",
                "img",
                "1.2.3",
                self.digests,
                self.sboms,
            ],
            env=e,
            check=False,
        )
        self.assertNotEqual(rc, 0, out)
        self.assertIn("CERT_IDENTITY", out)


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
