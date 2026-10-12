#!/usr/bin/env python3
"""Tests for release-tag.sh.

They generate throwaway keys in a temporary gpg homedir and use a local bare
repository as origin; no network and no real signing key are involved.
Skipped when git or gpg is unavailable, unless
FULMEN_TOOLBOX_REQUIRE_CRYPTO_TOOLS=1, which makes a missing tool a failure.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "release-tag.sh"
VERSION = "1.2.3"
TAG = "v" + VERSION
TAGGER_NAME = "Release Tagger"
TAGGER_EMAIL = "tagger@example.test"
TOOLS = ("git", "gpg", "gpgconf", "bash")


def clean_env():
    """Drop ambient FULMEN_TOOLBOX_*, GNUPGHOME and GIT_* variables so the
    operator's release environment can never leak into a test."""
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


def run_err(cwd, env, *args, stdin=None):
    proc = subprocess.run(
        args,
        cwd=cwd,
        env=env,
        input=stdin,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    return proc.stdout, proc.returncode


def run(cwd, env, *args, stdin=None):
    out, rc = run_err(cwd, env, *args, stdin=stdin)
    if rc != 0:
        raise AssertionError(f"{' '.join(args)}: exit {rc}\n{out}")
    return out


def fingerprints(home, selector):
    out = run(
        None,
        clean_env(),
        "gpg",
        "--homedir",
        home,
        "--batch",
        "--with-colons",
        "--fixed-list-mode",
        "--list-keys",
        selector,
    )
    return [f.split(":")[9] for f in out.splitlines() if f.startswith("fpr:")]


class ReleaseKeys:
    """A primary with two signing subkeys, plus a foreign signing key."""

    def __init__(self):
        # Short path: gpg-agent sockets live in the homedir and macOS limits
        # socket paths to ~104 bytes, which the default temp dir can exceed.
        self.home = tempfile.mkdtemp(prefix="rtag-gpg-", dir="/tmp")
        os.chmod(self.home, 0o700)

        def gpg(*args):
            run(
                None,
                clean_env(),
                "gpg",
                "--homedir",
                self.home,
                "--batch",
                "--pinentry-mode",
                "loopback",
                "--passphrase",
                "",
                *args,
            )

        gpg(
            "--quick-gen-key",
            f"{TAGGER_NAME} <{TAGGER_EMAIL}>",
            "ed25519",
            "cert",
            "never",
        )
        primary = fingerprints(self.home, TAGGER_EMAIL)[0]
        gpg("--quick-add-key", primary, "ed25519", "sign", "never")
        gpg("--quick-add-key", primary, "ed25519", "sign", "never")
        fprs = fingerprints(self.home, primary)
        if len(fprs) != 3:
            raise AssertionError(f"expected primary + 2 subkeys, got {fprs}")
        gpg(
            "--quick-gen-key",
            "Foreign Signer <foreign@example.test>",
            "ed25519",
            "sign",
            "never",
        )
        self.primary, self.sign_a, self.sign_b = fprs
        self.foreign = fingerprints(self.home, "foreign@example.test")[0]

    def close(self):
        run_err(None, clean_env(), "gpgconf", "--homedir", self.home, "--kill", "all")
        shutil.rmtree(self.home, ignore_errors=True)


class ReleaseRepo:
    def __init__(self, case, keys):
        self.keys = keys
        self.root = tempfile.mkdtemp(prefix="rtag-repo-")
        case.addCleanup(shutil.rmtree, self.root, True)
        self.origin = os.path.join(self.root, "origin.git")
        self.clone = os.path.join(self.root, "clone")
        env = clean_env()
        run(
            self.root,
            env,
            "git",
            "init",
            "--quiet",
            "--bare",
            "--initial-branch=main",
            self.origin,
        )
        run(self.root, env, "git", "clone", "--quiet", self.origin, self.clone)
        for key, value in (
            ("user.name", "Ambient Committer"),
            ("user.email", "ambient@example.test"),
            ("commit.gpgsign", "false"),
        ):
            run(self.clone, env, "git", "config", key, value)
        run(self.clone, env, "git", "checkout", "--quiet", "-b", "main")
        Path(self.clone, "VERSION").write_text(VERSION + "\n")
        run(self.clone, env, "git", "add", "VERSION")
        run(self.clone, env, "git", "commit", "--quiet", "-m", "init")
        run(self.clone, env, "git", "push", "--quiet", "origin", "main")
        self.vars = {
            "FULMEN_TOOLBOX_RELEASE_TAG": TAG,
            "FULMEN_TOOLBOX_PGP_KEY_ID": keys.sign_a + "!",
            "FULMEN_TOOLBOX_GPG_HOMEDIR": keys.home,
            "FULMEN_TOOLBOX_TAGGER_NAME": TAGGER_NAME,
            "FULMEN_TOOLBOX_TAGGER_EMAIL": TAGGER_EMAIL,
        }

    def env(self):
        env = clean_env()
        env.update({k: v for k, v in self.vars.items() if v})
        return env

    def script(self, cmd, env=None):
        return run_err(self.clone, env or self.env(), "bash", str(SCRIPT), cmd)

    def git(self, *args, stdin=None):
        return run(self.clone, clean_env(), "git", *args, stdin=stdin)

    def local_tag_exists(self):
        return self.git("tag", "--list", TAG).strip() != ""

    def remote_tag_exists(self):
        return (
            self.git("ls-remote", "--tags", "origin", f"refs/tags/{TAG}").strip() != ""
        )

    def tagger_env(self, signing=True):
        env = clean_env()
        if signing:
            env["GNUPGHOME"] = self.keys.home
        env["GIT_COMMITTER_NAME"] = TAGGER_NAME
        env["GIT_COMMITTER_EMAIL"] = TAGGER_EMAIL
        return env

    def sign_tag_with(self, tag, selector):
        """Create a tag by hand, signed by an arbitrary key with the declared
        tagger identity, to exercise verify against the wrong signer."""
        run(
            self.clone,
            self.tagger_env(),
            "git",
            "-c",
            "gpg.program=gpg",
            "tag",
            "-s",
            "-u",
            selector,
            tag,
            "-m",
            f"Release {tag}",
        )

    def advance_origin(self):
        """Push a new commit to origin from a second clone, leaving the release
        clone behind origin/main."""
        other = os.path.join(self.root, "other")
        env = clean_env()
        run(None, env, "git", "clone", "--quiet", self.origin, other)
        run(
            other,
            env,
            "git",
            "-c",
            "user.name=Other",
            "-c",
            "user.email=other@example.test",
            "commit",
            "--quiet",
            "--allow-empty",
            "-m",
            "moved on",
        )
        run(other, env, "git", "push", "--quiet", "origin", "main")


class ReleaseTagTestCase(unittest.TestCase):
    keys = None

    @classmethod
    def setUpClass(cls):
        cls.keys = None
        for tool in TOOLS:
            if shutil.which(tool) is None:
                if os.environ.get("FULMEN_TOOLBOX_REQUIRE_CRYPTO_TOOLS") == "1":
                    raise AssertionError(
                        f"{tool} unavailable and FULMEN_TOOLBOX_REQUIRE_CRYPTO_TOOLS=1"
                    )
                raise unittest.SkipTest(f"{tool} unavailable")
        cls.keys = ReleaseKeys()

    @classmethod
    def tearDownClass(cls):
        if cls.keys is not None:
            cls.keys.close()

    def repo(self):
        return ReleaseRepo(self, self.keys)

    def expect_fail(self, out, rc, want):
        self.assertNotEqual(
            rc, 0, f"expected failure containing {want!r}, got success:\n{out}"
        )
        self.assertIn(want, out)
        self.assertNotIn(
            "verified: ", out, f"failure path printed a success line:\n{out}"
        )
        self.assertNotIn(
            "created signed local tag",
            out,
            f"failure path printed a success line:\n{out}",
        )

    def created(self):
        r = self.repo()
        out, rc = r.script("create")
        self.assertEqual(rc, 0, f"create failed:\n{out}")
        return r


class TestReleaseTagGuards(ReleaseTagTestCase):
    def test_missing_variables(self):
        for name in (
            "FULMEN_TOOLBOX_RELEASE_TAG",
            "FULMEN_TOOLBOX_PGP_KEY_ID",
            "FULMEN_TOOLBOX_GPG_HOMEDIR",
            "FULMEN_TOOLBOX_TAGGER_NAME",
            "FULMEN_TOOLBOX_TAGGER_EMAIL",
        ):
            with self.subTest(name=name):
                r = self.repo()
                r.vars[name] = ""
                out, rc = r.script("create")
                self.expect_fail(out, rc, f"{name} is required")
                self.assertFalse(
                    r.local_tag_exists(), "tag created despite missing variable"
                )

    def test_guards(self):
        keys = self.keys

        def write_dirty(r):
            Path(r.clone, "VERSION").write_text(VERSION + "\n\n")

        cases = [
            (
                "tag does not match VERSION",
                lambda r: r.vars.update(FULMEN_TOOLBOX_RELEASE_TAG="v9.9.9"),
                "does not match v<VERSION>",
            ),
            (
                "tag without v prefix",
                lambda r: r.vars.update(FULMEN_TOOLBOX_RELEASE_TAG=VERSION),
                "does not match v<VERSION>",
            ),
            ("dirty tree", write_dirty, "working tree is not clean"),
            (
                "not on main",
                lambda r: r.git("checkout", "--quiet", "-b", "other"),
                "release tags are created from main",
            ),
            (
                "HEAD ahead of origin/main",
                lambda r: r.git(
                    "commit", "--quiet", "--allow-empty", "-m", "local only"
                ),
                "does not match origin/main",
            ),
            (
                "tag exists locally",
                lambda r: r.git("tag", TAG),
                "already exists locally",
            ),
            (
                "tag exists on origin",
                lambda r: r.git("push", "--quiet", "origin", f"HEAD:refs/tags/{TAG}"),
                "already exists on origin",
            ),
            (
                "tagger email not a uid",
                lambda r: r.vars.update(
                    FULMEN_TOOLBOX_TAGGER_EMAIL="someone@example.test"
                ),
                "not a uid email",
            ),
            (
                "short key id rejected",
                lambda r: r.vars.update(FULMEN_TOOLBOX_PGP_KEY_ID=keys.sign_a[32:]),
                "must be a 40-hex fingerprint or 16-hex long key id",
            ),
            (
                "email selector rejected",
                lambda r: r.vars.update(FULMEN_TOOLBOX_PGP_KEY_ID=TAGGER_EMAIL),
                "must be a 40-hex fingerprint or 16-hex long key id",
            ),
            (
                "unknown key",
                lambda r: r.vars.update(FULMEN_TOOLBOX_PGP_KEY_ID="A" * 40),
                "does not match any key",
            ),
            (
                "unforced subkey rejected",
                lambda r: r.vars.update(FULMEN_TOOLBOX_PGP_KEY_ID=keys.sign_a),
                "names a subkey",
            ),
        ]
        for name, setup, want in cases:
            with self.subTest(name=name):
                r = self.repo()
                setup(r)
                out, rc = r.script("create")
                self.expect_fail(out, rc, want)
                if name not in ("tag exists locally", "tag exists on origin"):
                    self.assertFalse(
                        r.local_tag_exists(), "tag created despite failed guard"
                    )

    def test_tagger_email_failure_lists_key_uids(self):
        r = self.repo()
        r.vars["FULMEN_TOOLBOX_TAGGER_EMAIL"] = "someone@example.test"
        out, _ = r.script("create")
        self.assertIn(f"{TAGGER_NAME} <{TAGGER_EMAIL}>", out)

    def test_ambiguous_selector(self):
        # A real 64-bit key id collision cannot be generated, so a gpg shim
        # reports two keys that share the selected long id.
        keys = self.keys
        r = self.repo()
        shim_dir = os.path.join(r.root, "shim")
        os.mkdir(shim_dir)
        long_id = keys.sign_a[24:]
        listing = "\n".join(
            [
                f"pub:u:255:22:{keys.primary[24:]}:1:::u:::cC::::::23::0:",
                f"fpr:::::::::{keys.primary}:",
                f"sub:u:255:22:{long_id}:1::::::s::::::23:",
                f"fpr:::::::::{keys.sign_a}:",
                f"pub:u:255:22:{long_id}:1:::u:::scSC::::::23::0:",
                f"fpr:::::::::{'B' * 24}{long_id}:",
            ]
        )
        shim = Path(shim_dir, "gpg")
        shim.write_text(f"#!/usr/bin/env bash\ncat <<'EOF'\n{listing}\nEOF\n")
        shim.chmod(0o700)
        r.vars["FULMEN_TOOLBOX_PGP_KEY_ID"] = long_id + "!"
        env = r.env()
        env["PATH"] = shim_dir + os.pathsep + env.get("PATH", "")
        out, rc = r.script("create", env=env)
        self.expect_fail(out, rc, "is ambiguous")
        self.assertFalse(r.local_tag_exists(), "tag created despite ambiguous selector")


class TestReleaseTagSignatureChecks(ReleaseTagTestCase):
    def test_forced_key_rejects_sibling_subkey(self):
        r = self.repo()
        r.sign_tag_with(TAG, self.keys.sign_b + "!")
        out, rc = r.script("verify")
        self.expect_fail(out, rc, "not the selected key")

    def test_forced_key_rejects_foreign_key(self):
        r = self.repo()
        r.sign_tag_with(TAG, self.keys.foreign)
        out, rc = r.script("verify")
        self.expect_fail(out, rc, "not the selected key")

    def test_unforced_primary_rejects_foreign_key(self):
        r = self.repo()
        r.vars["FULMEN_TOOLBOX_PGP_KEY_ID"] = self.keys.primary
        r.sign_tag_with(TAG, self.keys.foreign)
        out, rc = r.script("verify")
        self.expect_fail(out, rc, "was signed under primary")

    def test_tampered_tag_fails(self):
        r = self.repo()
        r.sign_tag_with(TAG, self.keys.sign_a + "!")
        obj = r.git("cat-file", "tag", TAG)
        tampered = obj.replace(f"Release {TAG}", "Release v1.2.4", 1)
        sha = r.git("hash-object", "-t", "tag", "-w", "--stdin", stdin=tampered).strip()
        r.git("update-ref", f"refs/tags/{TAG}", sha)
        out, rc = r.script("verify")
        self.expect_fail(out, rc, "git verify-tag failed")
        out, rc = r.script("push")
        self.expect_fail(out, rc, "git verify-tag failed")
        self.assertFalse(
            r.remote_tag_exists(), "push published a tag that failed verification"
        )

    def test_verbatim_message_without_trailing_newline_fails(self):
        # With --cleanup=verbatim and no trailing newline, git appends the
        # signature to the message line and cannot find it.
        r = self.repo()
        run(
            r.clone,
            r.tagger_env(),
            "git",
            "-c",
            "gpg.program=gpg",
            "tag",
            "-s",
            "-u",
            self.keys.sign_a + "!",
            "--cleanup=verbatim",
            TAG,
            "-m",
            f"Release {TAG}",
        )
        obj = r.git("cat-file", "-p", TAG)
        self.assertIn(
            f"Release {TAG}-----BEGIN PGP SIGNATURE-----",
            obj,
            "fixture did not reproduce the joined signature layout",
        )
        out, rc = r.script("verify")
        self.expect_fail(out, rc, "git verify-tag failed")
        out, rc = r.script("push")
        self.expect_fail(out, rc, "git verify-tag failed")
        self.assertFalse(
            r.remote_tag_exists(), "push published a tag that failed verification"
        )

    def test_unsigned_annotated_tag_fails(self):
        r = self.repo()
        run(
            r.clone,
            r.tagger_env(signing=False),
            "git",
            "tag",
            "-a",
            TAG,
            "-m",
            f"Release {TAG}",
        )
        out, rc = r.script("verify")
        self.expect_fail(out, rc, "git verify-tag failed")

    def test_lightweight_tag_fails(self):
        r = self.repo()
        r.git("tag", TAG)
        out, rc = r.script("verify")
        self.expect_fail(out, rc, "is not an annotated tag object")

    def test_tag_object_for_another_version_fails(self):
        r = self.repo()
        r.sign_tag_with("v1.2.4", self.keys.sign_a + "!")
        r.git(
            "update-ref",
            f"refs/tags/{TAG}",
            r.git("rev-parse", "refs/tags/v1.2.4").strip(),
        )
        out, rc = r.script("push")
        self.expect_fail(out, rc, "records a different tag name")
        self.assertFalse(
            r.remote_tag_exists(), "push published a tag that failed verification"
        )


class TestReleaseTagPushGuards(ReleaseTagTestCase):
    def test_origin_already_has_the_tag(self):
        r = self.created()
        r.git("push", "--quiet", "origin", f"HEAD:refs/tags/{TAG}")
        out, rc = r.script("push")
        self.expect_fail(out, rc, "already exists on origin")

    def test_head_behind_origin_main(self):
        r = self.created()
        r.advance_origin()
        out, rc = r.script("push")
        self.expect_fail(out, rc, "does not match origin/main")
        self.assertFalse(
            r.remote_tag_exists(), "push published the tag from a stale main"
        )

    def test_dirty_tree(self):
        r = self.created()
        Path(r.clone, "untracked").write_text("x")
        out, rc = r.script("push")
        self.expect_fail(out, rc, "working tree is not clean")
        self.assertFalse(
            r.remote_tag_exists(), "push published the tag from a dirty tree"
        )

    def test_pushes_only_the_release_tag(self):
        r = self.created()
        r.git("tag", "stray-local-tag")
        before = r.git("ls-remote", "--heads", "origin")
        out, rc = r.script("push")
        self.assertEqual(rc, 0, f"push failed:\n{out}")
        self.assertIn(f"pushed {TAG} only", out)
        self.assertEqual(
            r.git("ls-remote", "--heads", "origin"), before, "push moved branches"
        )
        tags = r.git("ls-remote", "--tags", "origin").strip()
        want = (
            r.git("rev-parse", f"refs/tags/{TAG}").strip()
            + f"\trefs/tags/{TAG}\n"
            + r.git("rev-parse", "HEAD").strip()
            + f"\trefs/tags/{TAG}^{{}}"
        )
        self.assertEqual(tags, want)

    def test_remote_override_is_ignored(self):
        r = self.created()
        decoy = os.path.join(r.root, "decoy.git")
        run(
            None,
            clean_env(),
            "git",
            "init",
            "--quiet",
            "--bare",
            "--initial-branch=main",
            decoy,
        )
        r.git("remote", "add", "decoy", decoy)
        r.vars["RELEASE_REMOTE"] = "decoy"
        r.vars["FULMEN_TOOLBOX_RELEASE_REMOTE"] = "decoy"
        out, rc = r.script("push")
        self.assertEqual(rc, 0, f"push failed:\n{out}")
        self.assertTrue(r.remote_tag_exists(), "tag was not pushed to origin")
        self.assertEqual(
            r.git("ls-remote", "decoy").strip(),
            "",
            "push wrote to a remote other than origin",
        )


class TestReleaseTagHappyPath(ReleaseTagTestCase):
    def test_forced_signing_subkey_create_verify_push(self):
        r = self.repo()
        out, rc = r.script("create")
        self.assertEqual(rc, 0, f"create failed:\n{out}")
        self.assertIn(f"signer:  {self.keys.sign_a}", out)
        self.assertIn(f"primary: {self.keys.primary}", out)
        self.assertEqual(r.git("cat-file", "-t", TAG).strip(), "tag")
        obj = r.git("cat-file", "-p", TAG)
        self.assertIn(f"\ntagger {TAGGER_NAME} <{TAGGER_EMAIL}> ", obj)
        self.assertIn(f"\n\nRelease {TAG}\n-----BEGIN PGP SIGNATURE-----", obj)

        out, rc = r.script("push")
        self.assertEqual(rc, 0, f"push failed:\n{out}")
        local = r.git("rev-parse", f"refs/tags/{TAG}").strip()
        remote = r.git("ls-remote", "--tags", "origin", f"refs/tags/{TAG}").split()[0]
        self.assertEqual(local, remote)
        heads = r.git("ls-remote", "--heads", "origin").strip()
        self.assertEqual(heads.count("\n"), 0, f"push touched branches:\n{heads}")

    def test_forced_long_key_id(self):
        r = self.repo()
        r.vars["FULMEN_TOOLBOX_PGP_KEY_ID"] = self.keys.sign_a[24:].lower() + "!"
        out, rc = r.script("create")
        self.assertEqual(rc, 0, f"create failed:\n{out}")
        self.assertIn(f"signer:  {self.keys.sign_a}", out)

    def test_unforced_primary_signs_with_a_live_subkey(self):
        r = self.repo()
        r.vars["FULMEN_TOOLBOX_PGP_KEY_ID"] = self.keys.primary
        out, rc = r.script("create")
        self.assertEqual(rc, 0, f"create failed:\n{out}")
        self.assertTrue(
            f"signer:  {self.keys.sign_a}" in out
            or f"signer:  {self.keys.sign_b}" in out,
            f"signer is not one of the primary's signing subkeys:\n{out}",
        )


if __name__ == "__main__":
    unittest.main()
