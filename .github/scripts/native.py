"""Rebuild only proven native outputs; never discard packaged siblings."""

import argparse
from pathlib import Path
import re
import shutil


PRODUCT = "Address Book"
BASE = Path("Address Book.4dbase/Plugins")
BUNDLE = BASE / (PRODUCT + ".bundle")
FILES = tuple(BUNDLE / relative for relative in (
    f"Contents/MacOS/{PRODUCT}", "Contents/Info.plist",
    "Contents/Resources/English.lproj/InfoPlist.strings",
    "Contents/Resources/constants.xlf", "Contents/Resources/manifest.json",
    "Contents/_CodeSignature/CodeResources",
))
XCODE_DATA = Path(".4dbase/Plugins/XCBuildData")
DIRECTORIES = (
    BASE / (PRODUCT + ".build"),
    BASE / "ExplicitPrecompiledModules",
    BASE / "SwiftExplicitPrecompiledModules",
    BASE / "EagerLinkingTBDs/Default",
)


def generated(path):
    return (path in set(map(str, FILES))
            or bool(re.fullmatch(
                re.escape(str(XCODE_DATA)) + r"/(?:build\.db(?:-wal|-shm)?|"
                r"[0-9a-f]{32}\.xcbuilddata/.+)", path))
            or any(path.startswith(str(directory) + "/")
                   for directory in DIRECTORIES))


def validate_paths(paths):
    root = Path.cwd().resolve()
    for path in paths:
        for parent in (path, *path.parents):
            if parent == Path("."):
                break
            if parent.is_symlink():
                raise ValueError(f"Refusing symlink output: {parent}")
        if not path.resolve().is_relative_to(root):
            raise ValueError(f"Output escapes checkout: {path}")
        if path.is_dir():
            for descendant in path.rglob("*"):
                if descendant.is_symlink():
                    raise ValueError(f"Refusing symlink output: {descendant}")
                if descendant.name == ".git":
                    raise ValueError(f"Refusing nested Git marker: {descendant}")
                if not descendant.is_file() and not descendant.is_dir():
                    raise ValueError(f"Unsupported output type: {descendant}")


def prepare():
    files = FILES
    directories = DIRECTORIES
    validate_paths((*files, *directories, XCODE_DATA))
    for path in files:
        if path.exists() and not path.is_file():
            raise ValueError(f"Expected generated file: {path}")
    for path in (*directories, XCODE_DATA):
        if path.exists() and not path.is_dir():
            raise ValueError(f"Expected generated directory: {path}")
    for path in files:
        path.unlink(missing_ok=True)
    for path in directories:
        if path.exists():
            shutil.rmtree(path)


def require_file(path):
    validate_paths((path,))
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"Missing or empty native output: {path}")


def verify_leaves(*, signed=False):
    for path in FILES if signed else FILES[:-1]:
        require_file(path)


def verify_resources():
    for name in ("manifest.json", "constants.xlf"):
        copied = BUNDLE / "Contents/Resources" / name
        require_file(copied)
        if copied.read_bytes() != Path(name).read_bytes():
            raise ValueError(f"Copied resource differs from source: {copied}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("clean-macos", "verify-resources",
                                        "verify-unsigned", "verify-final"))
    phase = parser.parse_args().phase
    if phase == "clean-macos":
        prepare()
    elif phase == "verify-resources":
        verify_resources()
    else:
        verify_leaves(signed=phase == "verify-final")
        verify_resources()
