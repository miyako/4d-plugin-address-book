"""Narrow macOS cleanup and final-only output retention."""

import shutil
from unittest import mock

from helper_support import Fixture, GitFixture, cwd
import native
import repository


class NativePreparationTests(Fixture):
    def test_unsigned_gate_does_not_require_signature_but_final_gate_does(self):
        for path in native.FILES[:-1]:
            self.write(path, b"fresh")
        with cwd(self.root):
            native.verify_leaves()
            with self.assertRaises(ValueError):
                native.verify_leaves(signed=True)
            self.write(native.FILES[-1], b"signature")
            native.verify_leaves(signed=True)

    def test_wrong_late_type_and_nested_git_marker_fail_before_first_deletion(self):
        first = self.write(native.FILES[0], b"preserve until every target validated")
        late = self.root / native.FILES[-1]
        late.mkdir(parents=True)
        with cwd(self.root), self.assertRaises(ValueError):
            native.prepare()
        self.assertTrue(first.is_file())
        late.rmdir()
        marker = self.write(native.DIRECTORIES[-1] / ".git", b"gitdir: anywhere")
        with cwd(self.root), self.assertRaises(ValueError):
            native.prepare()
        self.assertTrue(first.is_file())
        self.assertTrue(marker.is_file())

    def test_selective_cleanup_preserves_resources_dependencies_and_default_siblings(self):
        protected = (
            native.BUNDLE / "Contents/QuickLook/Thumbnail.png",
            native.BUNDLE / "Contents/MacOS/runtime.dylib",
            native.BUNDLE / "Contents/Resources/custom.txt",
            native.BASE / "Default/Address Book.bundle/Contents/Info.plist",
            native.BASE / "Default/keep", native.BASE / "Other.bundle/keep",
            "build/unrelated/keep", "a/libjsoncpp.a", "lib/windows64/jsoncpp.lib",
        )
        for path in protected:
            self.write(path, b"preserved")
        for path in native.FILES:
            self.write(path, b"stale")
        for path in native.DIRECTORIES:
            self.write(path / "intermediate", b"stale")
        with cwd(self.root):
            native.prepare()
            native.prepare()
        for path in protected:
            self.assertEqual((self.root / path).read_bytes(), b"preserved")
        for path in (*native.FILES, *native.DIRECTORIES):
            self.assertFalse((self.root / path).exists(), path)

    def test_symlink_anywhere_prevalidated_before_first_deletion(self):
        for where in (native.FILES[-1], native.DIRECTORIES[-1], native.BUNDLE,
                      native.DIRECTORIES[0] / "nested/link"):
            with self.subTest(where=where):
                first = self.write(native.FILES[0], b"must remain")
                destination = self.write("outside/keep", b"untouched")
                link = self.root / where
                if link.is_dir():
                    shutil.rmtree(link)
                link.parent.mkdir(parents=True, exist_ok=True)
                link.symlink_to(destination)
                with cwd(self.root), self.assertRaisesRegex(ValueError, "symlink"):
                    native.prepare()
                if where != native.BUNDLE:
                    self.assertEqual(first.read_bytes(), b"must remain")
                self.assertEqual(destination.read_bytes(), b"untouched")
                link.unlink()

    def test_cleanup_io_error_is_fatal(self):
        self.write(native.FILES[0], b"stale")
        with cwd(self.root), mock.patch("pathlib.Path.unlink", side_effect=PermissionError("denied")):
            with self.assertRaises(PermissionError):
                native.prepare()
        self.write(native.DIRECTORIES[0] / "stale", b"stale")
        with cwd(self.root), mock.patch("shutil.rmtree", side_effect=PermissionError("denied")):
            with self.assertRaises(PermissionError):
                native.prepare()

    def test_resources_must_be_fresh_exact_source_copies(self):
        for name in ("constants.xlf", "manifest.json"):
            self.write(name, b"source")
            self.write(native.BUNDLE / "Contents/Resources" / name, b"source")
        with cwd(self.root):
            native.verify_resources()
            (native.BUNDLE / "Contents/Resources/constants.xlf").write_bytes(b"stale")
            with self.assertRaisesRegex(ValueError, "differs"):
                native.verify_resources()

    def test_xcode_data_is_not_recursively_cleaned(self):
        paths = (
            str(native.XCODE_DATA / "build.db"),
            str(native.XCODE_DATA / "unexpected-source.cpp"),
            str(native.XCODE_DATA / "evil.xcbuilddata/keep"),
        )
        for path in paths:
            self.write(path, b"preserve original bytes")
        with cwd(self.root):
            native.prepare()
        for path in paths:
            self.assertEqual((self.root / path).read_bytes(), b"preserve original bytes")


class GeneratedRetentionTests(GitFixture):
    def test_actual_xcode_database_wal_and_outputs_are_final_only(self):
        for relative in (
            *native.FILES,
            *(str(native.XCODE_DATA / p) for p in (
                "build.db", "build.db-wal", "build.db-shm",
                "0123456789abcdef0123456789abcdef.xcbuilddata/build-request.json")),
            *(str(p / "Objects-normal/arm64/main.o") for p in native.DIRECTORIES),
        ):
            target = self.local / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b"fresh native output")
        with cwd(self.local):
            with self.assertRaises(ValueError):
                repository.verify_checkout(self.sha, generated=native.generated)
            repository.verify_checkout(self.sha, generated=native.generated, final=True)

    def test_evil_siblings_and_protected_resource_never_gain_final_exemption(self):
        for relative in (
            str(native.XCODE_DATA) + "-evil/build.db",
            str(native.XCODE_DATA / "unexpected-source.cpp"),
            str(native.XCODE_DATA / "build.db-evil"),
            str(native.XCODE_DATA / "evil.xcbuilddata/build-request.json"),
            str(native.DIRECTORIES[0]) + "-evil/main.o",
            "build/unexpected-source.cpp",
            "Objs/Release-evil/main.obj",
            "Objs/Debug/main.obj",
            "winbuild/nested/Address Book.4DX",
            str(native.BASE / "Default/Address Book.bundle/Contents/Info.plist"),
            str(native.BUNDLE / "Contents/QuickLook/Thumbnail.png"),
            str(native.BUNDLE / "Contents/MacOS/runtime.dylib"),
            str(native.BUNDLE / "Contents/Resources/custom.txt"),
            str(native.BUNDLE / "Contents/_CodeSignature/evil"),
        ):
            with self.subTest(relative=relative):
                target = self.local / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b"unexpected")
                with cwd(self.local), self.assertRaises(ValueError):
                    repository.verify_checkout(self.sha, generated=native.generated, final=True)
                target.unlink()
