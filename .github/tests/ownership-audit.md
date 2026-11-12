# 4D native ownership audit (Address Book)

Baseline: `a480191b7a6767f90a386c36e2441eda8c463b0d`.
Guidance: miyako/skills `4d-skills/skills/4dplugin/SKILL.md`, blob `aabdd402ca8bd87be6c84a1a61f2118ad4d4cb13`.
Issue: #4.

## Defect fixed: callback listener (`listenerLoopExecuteMethod`)
- **Empty owners overwritten.** The parameters were created with `eVK_Unistring`, which allocates an empty text owner. The shallow `PA_SetStringVariable` then overwrote that owner without releasing it, leaking 3 strings per notification (4 on the `EXECUTE METHOD` / 1007 fallback).
- **Result discarded.** The `PA_Variable` returned by `PA_ExecuteMethodByID` / `PA_ExecuteCommandByID` was discarded. A text or picture result leaked.
- **Fix.**
  - Create the parameters as `eVK_Undefined` and set each one once.
  - Capture `PA_GetLastError()` immediately after execution.
  - Clear the parameters.
  - Clear the result only when the call returned `eER_NoErr`; the result is unspecified on failure.

Reachability: `AB SET NOTIFICATION METHOD` (command 36) → `addressbookChanged:` → `listenerLoop` → `listenerLoopExecuteMethod`. Execution is synchronous; `CALLBACK_IN_NEW_PROCESS` is 0.

## Harness
`.github/tests/test_ownership.py` compiles the real `4DPlugin.cpp`, `4DPlugin.h` and the complete, unchanged bundled `4D Plugin API` (blob hashes are pinned) with ASan/UBSan. It links them against a synthetic engine (`ownership_host.mm`) that tracks string, picture and handle owners and aborts on invalid or double disposal.

AddressBook, Contacts, Security, process, workspace and image boundaries are stubbed through `ownership_platform.h` and deny by default. The harness never touches Contacts, TCC or the network. `nm` and `otool` checks reject forbidden imports.

Coverage:
- **Callbacks (144 cases).** Method ID vs 1007 fallback × ASCII/BMP/supplementary/empty text × null vs allocated empty parameters × undefined/text/picture result × success/command failure/handle failure.
- **Controls (17).** Dispatcher, array, scalar and platform-isolation checks.
- **Isolated expected-failure probes (6).** Each runs in its own process with an asserted exit status and marker.

Results with the same harness:
- Baseline `git archive`: 88 failures, which exactly match the predicted set (every allocated case, plus text/picture results on success).
- Fixed tree: 170/170 pass.

## Deferred (not changed)
- **`AB SET PERSON IMAGE`.** The `CGImageRef` from `PA_CreateNativePictureForScreen` is never released or NULL-checked. The SDK does not specify ownership of native pictures.
- **`ARRAY TEXT` resize failure.** Behavior when resizing fails under out-of-memory conditions is not covered; the allocator contract is missing.
- **Copy-unsafe wrappers.** Raw-owning wrapper classes could be copied implicitly in a way that is unsafe, but plugin code makes no such copies.
- **Dormant code.** The `C_PICTURE`, `C_POINTER` and `C_BLOB` helpers are unused.
- **Not verified.**
  - Native Windows: the vcxproj compiles macOS-only sources.
  - A real 4D host.
  - Real Contacts.
  - LSan leak detection.
  - Packed-struct alignment: the harness compiles with `-fno-sanitize=alignment` because `EngineBlock` is `pack(2)`.
