#!/usr/bin/env python3
"""Native ownership harness for the Address Book plugin (standard library only).

Builds the unchanged bundled 4D plugin SDK, its wrapper classes and the plugin
sources (4DPlugin.cpp, dispatcher) with ASan/UBSan against a synthetic engine
host (ownership_host.mm). AddressBook/Contacts are never linked: deny-by-default
stubs stand in for them, so no real Contacts data, TCC prompt, network, UI or
process is touched. Each case runs in its own process.

OWNERSHIP_SOURCE_ROOT selects the plugin/SDK tree to compile (default: this
checkout), so the same harness can be run against a `git archive` baseline.
"""
import concurrent.futures
import hashlib
import itertools
import os
import pathlib
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = pathlib.Path(os.environ.get("OWNERSHIP_SOURCE_ROOT", ROOT)).resolve()
API = SOURCE / "4D Plugin API"

# Exact git blob ids of the complete bundled SDK; never edited by the plugin.
SDK_BLOBS = {
    "4D Plugin API/4DPluginAPI.c": "478081f0238f6bc5393222f574bc2656f010b67b",
    "4D Plugin API/4DPluginAPI.h": "9054b45ffc7ff6f5b8d57529a3788a55d977b314",
    "4D Plugin API/4DPluginAPI.def": "996ecc4ab11ad165de9192eba2e7478db141c757",
    "4D Plugin API/EntryPoints.h": "730f2f77ff2713fb2fe4b7d6562baeedf5f664cb",
    "4D Plugin API/Flags.h": "10a83185333dac06a62dda61b9f9428243d1e2ee",
    "4D Plugin API/PrivateTypes.h": "77053dc0c0a3718d2d3b6f158371a6af78c6ae66",
    "4D Plugin API/PublicTypes.h": "2bb392e73e9c556c274fe0a75b3a6b83e310b77c",
}

# Platform imports that must never be reachable from the compiled plugin object.
FORBIDDEN_PLUGIN_IMPORTS = [
    "_OBJC_CLASS_$_NSTask",
    "_OBJC_CLASS_$_NSWorkspace",
    "_OBJC_CLASS_$_NSRunningApplication",
    "_OBJC_CLASS_$_NSImage",
    "_OBJC_CLASS_$_NSBundle",
    "_OBJC_CLASS_$_NSUUID",
    "_OBJC_CLASS_$_NSNotificationCenter",
    "_NSClassFromString",
    "_SecTaskCreateFromSelf",
    "_SecTaskCopyValueForEntitlement",
]

PATHS = ["method", "fallback"]
TEXTS = ["ascii", "bmp", "supplementary", "empty"]
EMPTIES = ["allocated", "null"]
RESULTS = ["undefined", "text", "picture"]
FAILURES = ["none", "command", "handle"]

OTHER_CASES = [
    "platform:isolation",
    "dispatcher:get-method",
    "array:wrapper-undefined:allocated",
    "array:wrapper-undefined:null",
    "array:wrapper-existing:allocated",
    "array:wrapper-existing:null",
    "array:accept-index0",
    "array:accept-last",
    "array:reject-negative",
    "array:reject-past-end",
    "array:reject-null-ustr",
    "array:reject-wrong-kind",
    "array:reject-null-data",
    "scalar:return:allocated",
    "scalar:return:null",
    "scalar:param:allocated",
    "scalar:param:null",
]

# name -> (expected return code, expected stderr/stdout marker)
PROBES = {
    "probe:shallow-overwrite-leak": (1, "leaked strings=1"),
    "probe:alias-double-clear": (-signal.SIGABRT, "VIOLATION invalid-dispose string"),
    "probe:clear-failed-result": (-signal.SIGABRT, "VIOLATION invalid-dispose string"),
    "probe:denied-selector": (-signal.SIGABRT, "DENY -[ABAddressBook people]"),
    "probe:denied-class": (-signal.SIGABRT, "DENY ABRecord"),
    "probe:denied-function": (-signal.SIGABRT, "DENY ABCopyLocalizedPropertyOrLabel"),
}

ENV = dict(
    os.environ,
    ASAN_OPTIONS="detect_leaks=0:halt_on_error=1:abort_on_error=0",
    UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1",
)


def blob_id(path):
    data = path.read_bytes()
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


class Build:
    directory = None
    binary = None
    plugin_object = None
    error = None

    @classmethod
    def ensure(cls):
        if cls.binary or cls.error:
            return
        try:
            cls._build()
        except Exception as exc:  # reported by every dependent test
            cls.error = str(exc)

    @classmethod
    def _build(cls):
        if sys.platform != "darwin":
            raise RuntimeError("macOS toolchain required")
        cls.directory = pathlib.Path(tempfile.mkdtemp(prefix="ab-ownership-"))
        flags = [
            "clang++", "-std=c++14", "-x", "objective-c++",
            "-include", str(HERE / "ownership_platform.h"),
            "-I", str(API), "-I", str(API / "Classes"), "-I", str(SOURCE),
            "-fsanitize=address,undefined", "-fno-sanitize=alignment",
            "-fno-sanitize-recover=undefined", "-g", "-O0", "-w", "-c",
        ]
        units = [(API / "4DPluginAPI.c", [])]
        units += [(p, []) for p in sorted((API / "Classes").glob("*.cpp"))]
        units += [(SOURCE / "4DPlugin.cpp", []), (HERE / "ownership_host.mm", ["-DOWNERSHIP_HOST=1"])]
        jobs = []
        for index, (src, extra) in enumerate(units):
            obj = cls.directory / f"{index:02d}-{src.stem}.o"
            jobs.append((flags + extra + [str(src), "-o", str(obj)], src, obj))
        with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count() or 2) as pool:
            results = list(pool.map(lambda job: (job, run(job[0])), jobs))
        for (cmd, src, obj), res in results:
            if res.returncode != 0:
                raise RuntimeError(f"compile failed: {src}\n{res.stderr[-4000:]}")
            if src.name == "4DPlugin.cpp":
                cls.plugin_object = obj
        binary = cls.directory / "ownership_host"
        res = run(["clang++", "-fsanitize=address,undefined"] + [str(o) for _, _, o in jobs]
                  + ["-framework", "Cocoa", "-framework", "Carbon", "-o", str(binary)])
        if res.returncode != 0:
            raise RuntimeError(f"link failed\n{res.stderr[-4000:]}")
        cls.binary = binary

    @classmethod
    def case(cls, name):
        cls.ensure()
        if cls.error:
            raise AssertionError(cls.error)
        return run([str(cls.binary), name], env=ENV, timeout=120)


def tearDownModule():
    if Build.directory and not os.environ.get("OWNERSHIP_KEEP_BUILD"):
        shutil.rmtree(Build.directory, ignore_errors=True)


class Identity(unittest.TestCase):
    def test_bundled_sdk_is_exact_and_unchanged(self):
        for rel, expected in SDK_BLOBS.items():
            with self.subTest(file=rel):
                self.assertEqual(blob_id(SOURCE / rel), expected)

    def test_plugin_object_has_no_platform_escape_imports(self):
        Build.ensure()
        self.assertIsNone(Build.error, Build.error)
        undefined = run(["nm", "-u", str(Build.plugin_object)]).stdout.split()
        for symbol in FORBIDDEN_PLUGIN_IMPORTS:
            with self.subTest(symbol=symbol):
                self.assertNotIn(symbol, undefined)
        self.assertIn("_PA_ExecuteMethodByID", undefined)
        self.assertIn("_PA_ExecuteCommandByID", undefined)

    def test_contacts_frameworks_are_not_linked(self):
        Build.ensure()
        self.assertIsNone(Build.error, Build.error)
        linked = run(["otool", "-L", str(Build.binary)]).stdout
        self.assertNotIn("AddressBook.framework", linked)
        self.assertNotIn("Contacts.framework", linked)
        self.assertNotIn("Security.framework", linked)


def _method_name(case):
    return "test_" + re.sub(r"[^0-9A-Za-z]+", "_", case)


def _passing(case):
    def test(self):
        res = Build.case(case)
        self.assertEqual(res.returncode, 0, f"{case}\n{res.stdout}{res.stderr[-3000:]}")
        self.assertIn(f"PASS {case}", res.stdout)
    return test


def _probe(case, code, marker):
    def test(self):
        res = Build.case(case)
        self.assertEqual(res.returncode, code, f"{case}\n{res.stdout}{res.stderr[-3000:]}")
        self.assertIn(marker, res.stdout + res.stderr)
    return test


class Callback(unittest.TestCase):
    """AB SET NOTIFICATION METHOD -> listener -> callback, two queued changes."""


for combo in itertools.product(PATHS, TEXTS, EMPTIES, RESULTS, FAILURES):
    name = "callback:" + ":".join(combo)
    setattr(Callback, _method_name(name), _passing(name))


class Controls(unittest.TestCase):
    """Dispatcher, ARRAY_TEXT transfer/rejection, C_TEXT scalar and isolation controls."""


for name in OTHER_CASES:
    setattr(Controls, _method_name(name), _passing(name))


class ExpectedFailureProbes(unittest.TestCase):
    """Isolated processes that must fail in exactly the named way."""


for name, (code, marker) in PROBES.items():
    setattr(ExpectedFailureProbes, _method_name(name), _probe(name, code, marker))


if __name__ == "__main__":
    unittest.main()
