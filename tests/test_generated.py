"""Exempt only researched Address Book leaves and intermediates."""

import unittest

from helper_support import source
import native


class GeneratedOutputTests(unittest.TestCase):
    def test_exact_native_files_and_controlled_directory_descendants(self):
        for path in (*map(str, native.FILES),
                     *(str(p / "nested/generated") for p in native.DIRECTORIES),
                     *(str(native.XCODE_DATA / name) for name in (
                         "build.db", "build.db-wal", "build.db-shm",
                         "0123456789abcdef0123456789abcdef.xcbuilddata/build-request.json"))):
            with self.subTest(path=path):
                self.assertTrue(native.generated(path))

    def test_every_resource_source_or_unproven_output_stays_protected(self):
        excluded = (
            *(str(native.BUNDLE / p) for p in (
                "Contents/Windows64/Address Book.4DX", "Contents/MacOS/runtime.dylib",
                "Contents/QuickLook/Thumbnail.png", "Contents/Resources/custom.txt",
                "Contents/Resources/Documentation/index.html",
                "Contents/_CodeSignature-evil/file", "Contents/Info.plist.backup")),
            str(native.BASE / "Default/Address Book.bundle/Contents/Info.plist"),
            str(native.BASE / "Default/keep"),
            str(native.BASE / "EagerLinkingTBDs/Development/keep"),
            *(str(native.XCODE_DATA / p) for p in (
                "unexpected-source.cpp", "build.db-evil",
                "evil.xcbuilddata/build-request.json")),
            str(native.XCODE_DATA) + "-evil/build.db",
            str(native.DIRECTORIES[0]) + "-evil/injected.cpp",
            "build/unexpected-source.cpp", "build/XCBuildData/build.db",
            *map(str, source.SOURCE_PATHS),
        )
        for path in excluded:
            with self.subTest(path=path):
                self.assertFalse(native.generated(path))
