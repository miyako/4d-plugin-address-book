![version](https://img.shields.io/badge/version-19%2B-5682DF)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-address-book)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-address-book/total)

See [4d-utility-sign-app](https://github.com/miyako/4d-utility-sign-app) on how to enable the plugin in 4D.

# 4d-pugin-address-book

Gives 4D direct access to macOS Contacts data through Apple's `AddressBook.framework` — people, groups, images, and vCards — plus a background-process notification mechanism that calls a 4D method whenever a record is inserted, updated, or deleted outside your database. Results come back as 4D `Text` (unique IDs, property values), `Boolean` and `Longint` (status/flags), `Picture` (contact photos), and one-dimensional arrays for anything multi-valued (phone numbers, group members, search results).

## Summary

| Command | Returns | Purpose |
|---|---|---|
| [AB TERMINATE](#ab-terminate) | — | Quit the Contacts app if it's running |
| [AB LAUNCH](#ab-launch) | — | Launch the Contacts app |
| [AB Create person](#ab-create-person) | Text | Create and save a new, empty person record |
| [AB Set person property](#ab-set-person-property) | Longint | Set one single-value property on a person |
| [AB Get person property](#ab-get-person-property) | Longint | Read one single-value property from a person |
| [AB Remove person](#ab-remove-person) | Longint | Delete a person record |
| [AB Set person properties](#ab-set-person-properties) | Longint | Replace a multi-value property (phones, emails, addresses, …) |
| [AB Get person properties](#ab-get-person-properties) | Longint | Read a multi-value property (values + labels) |
| [AB Set person image](#ab-set-person-image) | Longint | Set a person's contact photo |
| [AB Get person image](#ab-get-person-image) | Longint | Read a person's contact photo |
| [AB Person get vcard](#ab-person-get-vcard) | Longint | Export a person as vCard text |
| [AB QUERY PEOPLE](#ab-query-people) | — | Search for people matching one criterion |
| [AB Create person with vcard](#ab-create-person-with-vcard) | Text | Create and save a person from vCard text |
| [AB Set person flags](#ab-set-person-flags) | Longint | Set a person's raw AddressBook flags |
| [AB Get person flags](#ab-get-person-flags) | Longint | Read a person's raw AddressBook flags |
| [AB Get me](#ab-get-me) | Text | Get the unique ID of the "me" record |
| [AB Set me](#ab-set-me) | Longint | Set which person record is "me" |
| [AB Create group](#ab-create-group) | Text | Create and save a new group |
| [AB Set group name](#ab-set-group-name) | Longint | Rename a group |
| [AB Get group name](#ab-get-group-name) | Longint | Read a group's name |
| [AB Remove group](#ab-remove-group) | Longint | Delete a group |
| [AB Remove person from group](#ab-remove-person-from-group) | Longint | Remove a member from a group |
| [AB Add group to group](#ab-add-group-to-group) | Longint | Nest a group inside another group |
| [AB Add person to group](#ab-add-person-to-group) | Longint | Add a member to a group |
| [AB Remove group from group](#ab-remove-group-from-group) | Longint | Un-nest a subgroup |
| [AB Get people in group](#ab-get-people-in-group) | Longint | List a group's direct member people |
| [AB Get groups in group](#ab-get-groups-in-group) | Longint | List a group's direct subgroups |
| [AB Make date](#ab-make-date) | Text | Build an AddressBook-formatted date/time string |
| [AB GET DATE](#ab-get-date) | — | Parse an AddressBook date/time string |
| [AB Make address](#ab-make-address) | Text | Build an AddressBook-formatted address blob |
| [AB GET ADDRESS](#ab-get-address) | — | Parse an AddressBook address blob |
| [AB GET LIST](#ab-get-list) | — | List all/new/changed people or group unique IDs |
| [AB Get localized string](#ab-get-localized-string) | Text | Get the OS-localized label for a property/label name |
| [AB Get default country code](#ab-get-default-country-code) | Text | Read the system's default address country code |
| [AB Get default name ordering](#ab-get-default-name-ordering) | Longint | Read the system's default first/last name order |
| [AB Set notification method](#ab-set-notification-method) | Longint | Register a 4D method as the change-notification callback |
| [AB Get notification method](#ab-get-notification-method) | Longint | Read the currently registered callback method name |
| [AB Get parent groups](#ab-get-parent-groups) | Longint | List the groups a group directly belongs to |
| [AB LIST GROUP PEOPLE](#ab-list-group-people) | — | Bulk-dump name/company/ordering columns for a group (or everyone) |
| [AB FIND PEOPLE](#ab-find-people) | — | Search for people matching several combined criteria |
| [AB GET GROUP GROUPS](#ab-get-group-groups) | — | List the groups a group directly belongs to (UID only) |
| [AB GET PERSON GROUPS](#ab-get-person-groups) | — | List the groups a person directly belongs to |
| [AB REMOVE FROM PRIVACY LIST](#ab-remove-from-privacy-list) | — | Reset the app's Contacts privacy/TCC authorization |
| [AB Request permisson](#ab-request-permisson) | Longint | Request (and check) Contacts access permission |

**Platforms:** macOS only (Intel and Apple Silicon). There is no Windows build — Apple's Address Book/Contacts APIs this plugin drives don't exist on Windows, so this isn't a gap to work around, it's the whole platform surface.

---

## Requirements & platform notes

- **Call `AB Request permisson` once before anything else.** Every other command silently fails (returns `0`/empty) if Contacts access hasn't been granted — none of them raise a 4D error for a permission problem, so a `0` result is your only signal. See that command's own section for a race condition to be aware of on the very first call after install.
- **Code signing and entitlements are mandatory.** Your host app must be signed with the `com.apple.security.personal-information.addressbook` entitlement, and its `Info.plist` must include an `NSContactsUsageDescription` string (shown to the user in the system permission prompt). `AB Request permisson` checks for both and returns a distinct negative code for each one that's missing — see that command's reference below.
- **`AB Is access denied` was renamed to `AB Request permisson`.** If you're looking at older documentation or an older database, that's the same command under its current name.
- **On 4D v16/v17**, move `manifest.json` into the plugin's `Contents` folder (per the plugin's own packaging notes) — not a code-level concern, but a real installation gotcha for those versions.
- **Every command that identifies a person or group by `uniqueId` validates the format first** (an 8-4-4-4-12 hex UUID followed by `:ABPerson` or `:ABGroup`). A malformed or unrecognized ID never raises a 4D error or throws — the command just behaves as if nothing was found (status `0`, empty array, etc.).
- **Instant-messaging properties have a search gap.** `AIMInstant`, `JabberInstant`, `MSNInstant`, `YahooInstant`, and `ICQInstant` work fully with [`AB Set person properties`](#ab-set-person-properties)/[`AB Get person properties`](#ab-get-person-properties), but the internal property-name lookup used by [`AB QUERY PEOPLE`](#ab-query-people) and [`AB FIND PEOPLE`](#ab-find-people) doesn't recognize those five names — searching on them won't find matches. This is a real gap in the plugin's current source, not a documentation omission; there's no workaround at the command level today.
- **Status codes aren't a clean boolean.** Most "set" commands return `0` when nothing was found (bad ID, unrecognized property/key name) or the local update was rejected, `1` on success — but if 4D's own save-to-disk step (`saveAndReturnError:`) fails, the command returns Apple's raw `NSError` code for that failure instead, which can be any nonzero integer. Treat "not `1`" as "did not fully succeed," not just as a plain boolean.
- **`AB Set me` always reports success (`1`)**, even when passed a `uniqueId` that doesn't resolve to a real person — in that case it clears the "me" designation instead of setting it, and still reports `1`.
- **`AB Get groups in group` only writes its result array when the group has at least one subgroup.** If the group exists but has zero subgroups, the array parameter you passed in is left completely untouched (not even cleared) — this differs from the otherwise-identical [`AB Get people in group`](#ab-get-people-in-group), which always writes the array. Clear your array yourself immediately before calling it if you need to be sure of its state.
- **`AB Set notification method` is documented by the plugin as not thread-safe.** Call it from one consistent process/context in your app; don't call it concurrently from multiple processes.

---

## AB TERMINATE

### Syntax
```4d
AB TERMINATE
```

No parameters, no result.

### Description
Quits the Contacts app if — and only if — it's currently running (checked by bundle identifier `com.apple.AddressBook`). Does nothing if Contacts isn't open.

### Example
```4d
AB TERMINATE
```

---

## AB LAUNCH

### Syntax
```4d
AB LAUNCH
```

No parameters, no result.

### Description
Launches the Contacts app via `NSWorkspace`. Brings it to the front if it's already running.

### Example
```4d
AB LAUNCH
```

---

## AB Create person

### Syntax
```4d
AB Create person
```

| Parameter | Type | Description |
|---|---|---|
| Result | Text | Unique ID of the newly created, saved person |

### Description
Creates a new, blank `ABPerson` record and immediately saves it to the local Contacts database. On success, `Result` is the new record's unique ID — pass that ID straight into [`AB Set person property`](#ab-set-person-property) to fill it in. If the save fails (permission not granted, no default Contacts store, etc.), `Result` is empty; nothing is logged back to 4D beyond that.

### Example
From the plugin's own test method (`Method2.4dm`):
```4d
$p:=AB Create person()
AB Set person property($p; AB FirstName; "hello")
AB Set person property($p; AB LastName; "kittie")
```

---

## AB Set person property

### Syntax
```4d
AB Set person property ( uniqueId ; property ; value ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID (from `AB Create person`, `AB QUERY PEOPLE`, `AB GET LIST`, …) |
| `property` | Text | One of the property names below |
| `value` | Text | New value. Pass an empty text to clear the property |
| Result | Longint | `1` on success, `0` if the ID or property name wasn't recognized, or `AB Address Book`'s own error code if the save failed |

Valid `property` names: `FirstName`, `LastName`, `FirstNamePhonetic`, `LastNamePhonetic`, `Nickname`, `MaidenName`, `Birthday`, `Organization`, `JobTitle`, `Note`, `Department`, `MiddleName`, `MiddleNamePhonetic`, `Title`, `Suffix`.

### Description
Sets a single-value text property on an existing person. For `Birthday`, `value` must be a string `NSDate` can parse (e.g. the format produced by [`AB Make date`](#ab-make-date)); an unparseable value clears the birthday instead of setting it. For every other property, an empty `value` clears the existing value rather than leaving it unchanged.

### Example
From the plugin's own test methods (`CB_TEST.4dm`, `issue_2.4dm`):
```4d
ARRAY TEXT($records; 0)
AB QUERY PEOPLE(AB LastName; ""; ""; "宮下"; AB PrefixMatch; $records)

If (Size of array($records)#0)
	$person:=$records{1}
	$Note:="aaa"
	$result:=AB Set person property($person; AB Note; $Note)
End if
```

---

## AB Get person property

### Syntax
```4d
AB Get person property ( uniqueId ; property ; value ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| `property` | Text | One of the property names below |
| `value` | Text | (by reference) Receives the property's current value |
| Result | Longint | `1` if the person and property were found, `0` otherwise |

Valid `property` names: everything listed under [`AB Set person property`](#ab-set-person-property), plus two read-only properties: `CreationDate`, `ModificationDate`.

### Description
`Birthday`, `CreationDate`, and `ModificationDate` come back as the OS's default date/time description string, not a raw date — parse with [`AB GET DATE`](#ab-get-date) rather than expecting a specific locale-free format. If the property is genuinely unset on the record (e.g. no birthday), `value` is set to whatever `nil` renders as (an empty text) and `Result` is still `1`, since the person and property name were both valid.

### Example
From the plugin's own test methods (with the `Get` line commented out in the source, shown here active):
```4d
ARRAY TEXT($records; 0)
AB QUERY PEOPLE(AB LastName; ""; ""; "宮下"; AB PrefixMatch; $records)

If (Size of array($records)#0)
	$person:=$records{1}
	$Note:=""
	$result:=AB Get person property($person; AB Note; $Note)
End if
```

---

## AB Remove person

### Syntax
```4d
AB Remove person ( uniqueId ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| Result | Longint | `1` on success, `0` if the ID wasn't found, or the AddressBook error code if removal/save failed |

### Description
Removes the person record and saves the change. Membership in any groups is removed along with the record (standard `ABAddressBook` behavior — this plugin doesn't do anything extra to un-link groups first).

### Example
```4d
$result:=AB Remove person($personUID)
If ($result=1)
	ALERT("Contact deleted.")
End if
```

---

## AB Set person properties

### Syntax
```4d
AB Set person properties ( uniqueId ; property ; labels ; values ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| `property` | Text | One of the multi-value property names below |
| `labels` | Text array | Label for each entry (e.g. `"home"`, `"work"`) — array index 1 lines up with `values` index 1 |
| `values` | Text array | Value for each entry. For `Address`, each entry must be an XML property-list blob built by [`AB Make address`](#ab-make-address) |
| Result | Longint | `1` on success, `0` if the person or property name wasn't found, or the AddressBook error code if the save failed |

Valid `property` names: `URLs`, `CalendarURI`, `Email`, `Address`, `OtherDates`, `RelatedNames`, `Phone`, `AIMInstant`, `JabberInstant`, `MSNInstant`, `YahooInstant`, `ICQInstant`.

### Description
Entries with an empty `labels` value are skipped (logged internally, not reported back to 4D). Replaces the entire multi-value property — this is not an incremental append; pass every entry you want the property to end up containing. The first non-empty-label entry (array index 1) is also set as the property's primary/default entry.

### Example
```4d
ARRAY TEXT($labels; 2)
ARRAY TEXT($values; 2)
$labels{1}:="work"
$values{1}:="+1 555 0100"
$labels{2}:="mobile"
$values{2}:="+1 555 0101"

$result:=AB Set person properties($personUID; AB Phone; $labels; $values)
```

---

## AB Get person properties

### Syntax
```4d
AB Get person properties ( uniqueId ; property ; labels ; values ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| `property` | Text | One of the multi-value property names listed under [`AB Set person properties`](#ab-set-person-properties) |
| `labels` | Text array | (by reference) Receives each entry's label |
| `values` | Text array | (by reference) Receives each entry's value. For `Address`, each entry is an XML property-list blob — parse it with [`AB GET ADDRESS`](#ab-get-address) |
| Result | Longint | `1` if the person and property were found (even if there are zero entries), `0` otherwise |

### Description
`labels` and `values` are parallel arrays — index *n* of one always corresponds to index *n* of the other.

### Example
```4d
ARRAY TEXT($labels; 0)
ARRAY TEXT($emails; 0)

If (AB Get person properties($personUID; AB Email; $labels; $emails)=1)
	For ($i; 1; Size of array($emails))
		ALERT($labels{$i}+": "+$emails{$i})
	End for
End if
```

---

## AB Set person image

### Syntax
```4d
AB Set person image ( uniqueId ; picture ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| `picture` | Picture | New contact photo. Pass an empty picture to remove the photo |
| Result | Longint | `1` on success, `0` if the ID wasn't found, or the AddressBook error code if the save failed |

### Description
The picture is converted to a TIFF representation internally before being handed to `ABPerson`; you don't need to convert it yourself — any 4D `Picture` value works as input.

### Example
From the plugin's own test method (`Method2.4dm`):
```4d
READ PICTURE FILE(Get 4D folder(Current resources folder)+"octocat-gravatar.png"; $icon)
$success:=AB Set person image($UID{1}; $icon)
```

---

## AB Get person image

### Syntax
```4d
AB Get person image ( uniqueId ; picture ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| `picture` | Picture | (by reference) Receives the contact's photo |
| Result | Longint | `1` if the person was found (even with no photo set), `0` otherwise |

### Description
If the person has no photo, `picture` comes back as an empty picture and `Result` is still `1`. Calling this repeatedly on the same variable is safe — the plugin disposes of the previous picture handle before replacing it, so it won't leak memory across repeated calls in a loop.

### Example
From the plugin's own test method (`Method2.4dm`):
```4d
$success:=AB Get person image($UID{1}; $icon)
```

---

## AB Person get vcard

### Syntax
```4d
AB Person get vcard ( uniqueId ; vcard ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| `vcard` | Text | (by reference) Receives the vCard representation |
| Result | Longint | `1` on success, `0` if the person wasn't found or has no vCard representation |

### Description
The vCard is read as UTF-8 bytes and converted to 4D text — round-trips correctly with [`AB Create person with vcard`](#ab-create-person-with-vcard).

### Example
```4d
$result:=AB Person get vcard($personUID; $vcardText)
If ($result=1)
	DOCUMENT TO BLOB($vcardText; $blob) //or write $vcardText to a .vcf file with your own document commands
End if
```

---

## AB QUERY PEOPLE

### Syntax
```4d
AB QUERY PEOPLE ( property ; label ; key ; value ; comparison ; results )
```

| Parameter | Type | Description |
|---|---|---|
| `property` | Text | Property to search on — see the name list below |
| `label` | Text | Restrict the match to entries with this label; pass `""` to match any label |
| `key` | Text | For `Address` only: which sub-field to compare (`Street`, `City`, `State`, `ZIP`, `Country`, `CountryCode`); pass `""` for other properties |
| `value` | Text | Text to compare against. For `Birthday`/`ModificationDate`/`CreationDate`, must be a date string `NSDate` can parse |
| `comparison` | Text | `Equal`, `NotEqual`, `DoesNotContainSubString`, `PrefixMatch`, `ContainsSubString`, or `SuffixMatch` (all matches are case-insensitive) |
| `results` | Text array | (by reference) Receives every matching person's unique ID |

This command has no function result — matches are only reported through `results`, which is empty (size `0`) if nothing matched.

Valid `property` names: `FirstName`, `LastName`, `FirstNamePhonetic`, `LastNamePhonetic`, `Nickname`, `MaidenName`, `Birthday`, `Organization`, `JobTitle`, `Note`, `Department`, `MiddleName`, `MiddleNamePhonetic`, `Title`, `Suffix`, `URLs`, `CalendarURI`, `Email`, `Address`, `OtherDates`, `RelatedNames`, `Phone`, `ModificationDate`, `CreationDate`, `UID`. **Not supported for searching:** `AIMInstant`, `JabberInstant`, `MSNInstant`, `YahooInstant`, `ICQInstant` — see [Requirements & platform notes](#requirements--platform-notes).

### Description
A single-criterion search — for combining several criteria with AND/OR logic, use [`AB FIND PEOPLE`](#ab-find-people) instead. An unrecognized `property` name matches nothing (it's treated as searching for an impossible empty-string property) rather than raising an error, so double-check spelling if you get zero results unexpectedly.

### Example
From the plugin's own test method (`CB_TEST.4dm`/`issue_2.4dm`):
```4d
ARRAY TEXT($records; 0)
AB QUERY PEOPLE(AB LastName; ""; ""; "宮下"; AB PrefixMatch; $records)

If (Size of array($records)#0)
	$person:=$records{1}
End if
```

Searching by address city:
```4d
ARRAY TEXT($records; 0)
AB QUERY PEOPLE(AB Address; ""; AB City; "Cupertino"; AB Equal; $records)
```

---

## AB Create person with vcard

### Syntax
```4d
AB Create person with vcard ( vcard ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `vcard` | Text | vCard text (UTF-8) |
| Result | Text | Unique ID of the newly created, saved person; empty if the vCard couldn't be parsed or the save failed |

### Description
The inverse of [`AB Person get vcard`](#ab-person-get-vcard). The vCard text is encoded as UTF-8 before being handed to `ABPerson`'s vCard initializer.

### Example
```4d
$newUID:=AB Create person with vcard($vcardText)
If ($newUID#"")
	ALERT("Imported as "+$newUID)
End if
```

---

## AB Set person flags

### Syntax
```4d
AB Set person flags ( uniqueId ; flags ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| `flags` | Longint | Raw `kABPersonFlags` bitmask value (name-ordering bit, "show as company" bit, etc.) |
| Result | Longint | `1` on success, `0` if the ID wasn't found, or the AddressBook error code if the save failed |

### Description
This sets Apple's raw flags integer directly, with no bit-name constants of its own exposed by the plugin. If you need the individual meanings (name ordering, show-as-company), refer to Apple's `ABPerson` flags documentation for the bit layout, or read them back with [`AB Get person flags`](#ab-get-person-flags) and compare against a value you already know.

### Example
```4d
$currentFlags:=0
$success:=AB Get person flags($personUID; $currentFlags)
$result:=AB Set person flags($personUID; $currentFlags)  // round-trip, no bits changed
```

---

## AB Get person flags

### Syntax
```4d
AB Get person flags ( uniqueId ; flags ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| `flags` | Longint | (by reference) Receives the raw `kABPersonFlags` bitmask |
| Result | Longint | `1` if the person was found, `0` otherwise |

### Description
See [`AB Set person flags`](#ab-set-person-flags) for the caveat about bit-name constants.

### Example
```4d
$flags:=0
If (AB Get person flags($personUID; $flags)=1)
	ALERT(String($flags))
End if
```

---

## AB Get me

### Syntax
```4d
AB Get me
```

| Parameter | Type | Description |
|---|---|---|
| Result | Text | Unique ID of the record currently designated "me"; empty if none is set |

### Description
Mirrors macOS Contacts' own "My Card" concept.

### Example
```4d
$meUID:=AB Get me()
If ($meUID="")
	ALERT("No 'me' card is set.")
End if
```

---

## AB Set me

### Syntax
```4d
AB Set me ( uniqueId ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID to designate as "me" |
| Result | Longint | Always `1` |

### Description
**This command always returns `1`, whether or not `uniqueId` resolved to a real person.** If the ID is invalid or unrecognized, it clears the "me" designation instead of setting it — it does not report that as a failure. Confirm the effect afterward with [`AB Get me`](#ab-get-me) if you need to be certain the intended person was actually set.

### Example
```4d
$result:=AB Set me($personUID)  // always 1 — verify with AB Get me if it matters
```

---

## AB Create group

### Syntax
```4d
AB Create group
```

| Parameter | Type | Description |
|---|---|---|
| Result | Text | Unique ID of the newly created, saved group; empty if the save failed |

### Description
Creates a blank `ABGroup` and saves it immediately, the same pattern as [`AB Create person`](#ab-create-person).

### Example
```4d
$groupUID:=AB Create group()
$result:=AB Set group name($groupUID; "Book Club")
```

---

## AB Set group name

### Syntax
```4d
AB Set group name ( uniqueId ; name ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Group's unique ID |
| `name` | Text | New group name |
| Result | Longint | `1` on success, `0` if the ID wasn't found, or the AddressBook error code if the save failed |

### Example
```4d
$result:=AB Set group name($groupUID; "Book Club 2026")
```

---

## AB Get group name

### Syntax
```4d
AB Get group name ( uniqueId ; name ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Group's unique ID |
| `name` | Text | (by reference) Receives the group's name |
| Result | Longint | `1` if the group was found, `0` otherwise |

### Example
```4d
$name:=""
If (AB Get group name($groupUID; $name)=1)
	ALERT($name)
End if
```

---

## AB Remove group

### Syntax
```4d
AB Remove group ( uniqueId ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Group's unique ID |
| Result | Longint | `1` on success, `0` if the ID wasn't found, or the AddressBook error code if removal/save failed |

### Description
Deletes the group record. Member people are not deleted — only the group and its membership links.

### Example
```4d
$result:=AB Remove group($groupUID)
```

---

## AB Remove person from group

### Syntax
```4d
AB Remove person from group ( groupUniqueId ; personUniqueId ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `groupUniqueId` | Text | Group's unique ID |
| `personUniqueId` | Text | Person's unique ID |
| Result | Longint | `1` on success, `0` if either ID wasn't found or the person wasn't a member, or the AddressBook error code if the save failed |

### Example
```4d
$result:=AB Remove person from group($groupUID; $personUID)
```

---

## AB Add group to group

### Syntax
```4d
AB Add group to group ( groupUniqueId ; subgroupUniqueId ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `groupUniqueId` | Text | Parent group's unique ID |
| `subgroupUniqueId` | Text | Group to nest inside the parent |
| Result | Longint | `1` on success, `0` if either ID wasn't found, or the AddressBook error code if the save failed |

### Example
```4d
$result:=AB Add group to group($parentGroupUID; $childGroupUID)
```

---

## AB Add person to group

### Syntax
```4d
AB Add person to group ( groupUniqueId ; personUniqueId ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `groupUniqueId` | Text | Group's unique ID |
| `personUniqueId` | Text | Person's unique ID |
| Result | Longint | `1` on success, `0` if either ID wasn't found, or the AddressBook error code if the save failed |

### Example
```4d
$result:=AB Add person to group($groupUID; $personUID)
```

---

## AB Remove group from group

### Syntax
```4d
AB Remove group from group ( groupUniqueId ; subgroupUniqueId ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `groupUniqueId` | Text | Parent group's unique ID |
| `subgroupUniqueId` | Text | Nested group to remove |
| Result | Longint | `1` on success, `0` if either ID wasn't found, or the AddressBook error code if the save failed |

### Example
```4d
$result:=AB Remove group from group($parentGroupUID; $childGroupUID)
```

---

## AB Get people in group

### Syntax
```4d
AB Get people in group ( uniqueId ; people ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Group's unique ID |
| `people` | Text array | (by reference) Receives the unique ID of each direct member person |
| Result | Longint | `1` if the group has at least one member, `0` if the group wasn't found or has no members |

### Description
Only direct members — people belonging to a nested subgroup but not the group itself aren't included. `people` is always written (cleared to size `0` if there are no members), unlike its sibling below.

### Example
```4d
ARRAY TEXT($members; 0)
If (AB Get people in group($groupUID; $members)=1)
	ALERT(String(Size of array($members))+" members")
End if
```

---

## AB Get groups in group

### Syntax
```4d
AB Get groups in group ( uniqueId ; groups ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Group's unique ID |
| `groups` | Text array | (by reference) Receives the unique ID of each direct subgroup |
| Result | Longint | `1` if the group has at least one subgroup, `0` if the group wasn't found or has no subgroups |

### Description
**`groups` is only written when there's at least one subgroup.** If the group exists but has none, the array parameter is left completely untouched — clear it yourself beforehand if you need a reliable empty result. (This is the one place this pair of commands behaves differently from [`AB Get people in group`](#ab-get-people-in-group), which always writes its array.)

### Example
```4d
ARRAY TEXT($subgroups; 0)  // clear first — see note above
If (AB Get groups in group($groupUID; $subgroups)=1)
	ALERT(String(Size of array($subgroups))+" subgroups")
End if
```

---

## AB Make date

### Syntax
```4d
AB Make date ( date ; time ; timeZoneName ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `date` | Date | Calendar date |
| `time` | Time | Time of day, as a duration since midnight |
| `timeZoneName` | Text | IANA/`NSTimeZone` name (e.g. `"America/Los_Angeles"`); falls back to the local time zone if the name isn't recognized |
| Result | Text | AddressBook-formatted date/time description string |

### Description
Produces the same style of string `ABPerson`'s date-valued properties return, for use as the `value` in [`AB Set person property`](#ab-set-person-property) (`Birthday`) or [`AB QUERY PEOPLE`](#ab-query-people)/[`AB FIND PEOPLE`](#ab-find-people) (`Birthday`, `CreationDate`, `ModificationDate`). If `timeZoneName` is empty, `Result` is empty too — a time zone is mandatory for this command, unlike [`AB GET DATE`](#ab-get-date).

### Example
```4d
$dateString:=AB Make date(!2026-06-15!; ?09:30:00?; "America/New_York")
$result:=AB Set person property($personUID; AB Birthday; $dateString)
```

---

## AB GET DATE

### Syntax
```4d
AB GET DATE ( dateString ; date ; time ; offset )
```

| Parameter | Type | Description |
|---|---|---|
| `dateString` | Text | AddressBook-formatted date/time string (as returned by [`AB Get person property`](#ab-get-person-property) for `Birthday`/`CreationDate`/`ModificationDate`, or by [`AB Make date`](#ab-make-date)) |
| `date` | Date | (by reference) Receives the calendar date |
| `time` | Time | (by reference) Receives the time of day |
| `offset` | Longint | (by reference) Receives the UTC offset, in seconds |
| Result | — | No function result |

### Description
If `dateString` isn't in the expected 25-character format, `date`/`time`/`offset` are left at whatever they were passed in as (this command has no way to signal "couldn't parse" back to 4D other than that). Always pair this with strings this plugin itself produced or returned — don't hand it arbitrary user-typed date text.

### Example
```4d
$date:=!00-00-00!
$time:=?00:00:00?
$offset:=0
AB GET DATE($dateString; $date; $time; $offset)
```

---

## AB Make address

### Syntax
```4d
AB Make address ( street ; city ; state ; zip ; country ; countryCode ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `street` | Text | Street address |
| `city` | Text | City |
| `state` | Text | State/province |
| `zip` | Text | Postal code |
| `country` | Text | Country name |
| `countryCode` | Text | ISO country code (lower-cased automatically) |
| Result | Text | XML property-list blob suitable as a `value` entry for [`AB Set person properties`](#ab-set-person-properties) with `property` set to `Address` |

### Example
```4d
$addr:=AB Make address("1 Infinite Loop"; "Cupertino"; "CA"; "95014"; "United States"; "us")

ARRAY TEXT($labels; 1)
ARRAY TEXT($values; 1)
$labels{1}:="work"
$values{1}:=$addr
$result:=AB Set person properties($personUID; AB Address; $labels; $values)
```

---

## AB GET ADDRESS

### Syntax
```4d
AB GET ADDRESS ( addressData ; street ; city ; state ; zip ; country ; countryCode )
```

| Parameter | Type | Description |
|---|---|---|
| `addressData` | Text | XML property-list blob, e.g. one entry from [`AB Get person properties`](#ab-get-person-properties) with `property` set to `Address` |
| `street` | Text | (by reference) Receives the street |
| `city` | Text | (by reference) Receives the city |
| `state` | Text | (by reference) Receives the state/province |
| `zip` | Text | (by reference) Receives the postal code |
| `country` | Text | (by reference) Receives the country name |
| `countryCode` | Text | (by reference) Receives the ISO country code |
| Result | — | No function result |

### Description
If `addressData` isn't a valid property-list dictionary, every output parameter is left untouched — there's no error signal, so initialize your variables to a known "not filled in" value beforehand if you need to detect that case.

### Example
```4d
ARRAY TEXT($labels; 0)
ARRAY TEXT($addresses; 0)
If (AB Get person properties($personUID; AB Address; $labels; $addresses)=1)
	If (Size of array($addresses)>0)
		$street:=""; $city:=""; $state:=""; $zip:=""; $country:=""; $code:=""
		AB GET ADDRESS($addresses{1}; $street; $city; $state; $zip; $country; $code)
	End if
End if
```

---

## AB GET LIST

### Syntax
```4d
AB GET LIST ( type ; ids ; filter ; anchorDate )
```

| Parameter | Type | Description |
|---|---|---|
| `type` | Longint | `AB People` or `AB Groups` |
| `ids` | Text array | (by reference) Receives the unique ID of every matching record |
| `filter` | Longint | `AB RecordsAll`, or a "since a date" filter — see note below |
| `anchorDate` | Text | Required when `filter` is a "since" filter: an AddressBook-formatted date/time string (see [`AB Make date`](#ab-make-date)). Ignored for `AB RecordsAll` |
| Result | — | No function result |

### Description
With `filter` set to `AB RecordsAll`, this lists every person or every group unconditionally. The plugin's source also implements "created since" and "modified since" filters (comparing against `anchorDate`) — the plugin's own test file only demonstrates `AB RecordsAll`, so if you use a "since" filter, confirm its exact constant name in your 4D Explorer's constants list before relying on it; it follows the same `AB Records...` naming pattern as `AB RecordsAll` but wasn't independently confirmed against a sample here. `ids` is only written to if at least one record matches.

### Example
From the plugin's own test method (`Method2.4dm`):
```4d
ARRAY TEXT($UID; 0)
AB GET LIST(AB People; $UID; AB RecordsAll)
```

---

## AB Get localized string

### Syntax
```4d
AB Get localized string ( propertyOrLabel ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `propertyOrLabel` | Text | A raw AddressBook property or label constant name |
| Result | Text | The OS's localized, user-facing label for it |

### Description
Useful for turning a raw label like `_$!<Work>!$_` into the localized string the Contacts app itself would display, in the user's current OS language.

### Example
```4d
$label:=AB Get localized string("_$!<Work>!$_")
```

---

## AB Get default country code

### Syntax
```4d
AB Get default country code
```

| Parameter | Type | Description |
|---|---|---|
| Result | Text | The system's default address-formatting country code |

### Example
```4d
$code:=AB Get default country code()
```

---

## AB Get default name ordering

### Syntax
```4d
AB Get default name ordering
```

| Parameter | Type | Description |
|---|---|---|
| Result | Longint | The system's default first/last name display order (`kABFirstNameFirst`-style constant, raw integer) |

### Description
No named 4D constants are exposed for the possible values by this plugin — compare the raw integer against a value you already know, or cross-reference Apple's `ABPerson` name-ordering constants.

### Example
```4d
$ordering:=AB Get default name ordering()
```

---

## AB Set notification method

### Syntax
```4d
AB Set notification method ( methodName ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `methodName` | Text | Name of a 4D method to call whenever Contacts data changes outside your database |
| Result | Longint | `1` once the background monitor process has been started; no result at all if this is called again while the plugin is already shutting down |

### Description
Starts a dedicated background 4D process that listens for `kABDatabaseChangedExternallyNotification` and calls `methodName` with three `Text` parameters — inserted, updated, and deleted record IDs, each `\r`-separated (or a single positional parameter form if `methodName` doesn't resolve to a real method ID at call time; check the plugin's `LISTENER_METHOD` handling in source if you need the exact fallback shape). **Not thread-safe** — call this once, from one consistent place in your app, not concurrently from multiple processes.

### Example
From the plugin's own test method (`CALLBACK.4dm`):
```4d
AB Set notification method("CALLBACK")
$permisson:=AB Request permisson
```

Where the `CALLBACK` method itself looks like:
```4d
C_TEXT($1; $2; $3)
```

---

## AB Get notification method

### Syntax
```4d
AB Get notification method ( methodName ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `methodName` | Text | (by reference) Receives the currently registered callback method name (empty if none is set) |
| Result | Longint | Always `1` |

### Example
```4d
$name:=""
AB Get notification method($name)
```

---

## AB Get parent groups

### Syntax
```4d
AB Get parent groups ( uniqueId ; groups ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Group's unique ID |
| `groups` | Text array | (by reference) Receives the unique ID of every group this group directly belongs to |
| Result | Longint | `1` if at least one parent group was found, `0` otherwise |

### Description
Behaves toward `groups` the same way [`AB Get groups in group`](#ab-get-groups-in-group) does: the array is only written when there's at least one result.

### Example
```4d
ARRAY TEXT($parents; 0)
If (AB Get parent groups($groupUID; $parents)=1)
	ALERT(String(Size of array($parents))+" parent groups")
End if
```

---

## AB LIST GROUP PEOPLE

### Syntax
```4d
AB LIST GROUP PEOPLE ( uniqueId ; uids ; firstNames ; lastNames ; organizations ; firstNameFirst ; showAsCompany ; modificationDates ; modificationTimestamps )
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Group's unique ID, or an empty text to list every person in the entire address book |
| `uids` | Text array | (by reference) Unique ID of each person |
| `firstNames` | Text array | (by reference) First name (empty text if unset) |
| `lastNames` | Text array | (by reference) Last name (empty text if unset) |
| `organizations` | Text array | (by reference) Organization (empty text if unset) |
| `firstNameFirst` | Boolean array | (by reference) `True` if this person displays first-name-first (resolving the "use system default" case against the current system default) |
| `showAsCompany` | Boolean array | (by reference) `True` if this person is configured to display as a company |
| `modificationDates` | Text array | (by reference) Modification date, as its OS description string — parse with [`AB GET DATE`](#ab-get-date) |
| `modificationTimestamps` | Real array | (by reference) Modification date as a Mac absolute-time number (seconds since 2001-01-01) |
| Result | — | No function result |

### Description
All eight output arrays are always the same length and are only populated (starting from index 1) if there's at least one matching person — direct group members only, same as [`AB Get people in group`](#ab-get-people-in-group), not members of nested subgroups. Pass `uniqueId` as `""` to dump every person in the whole address book at once — useful for a one-shot sync, but potentially a large result set; the plugin yields to other processes periodically (every 8192 records) while building it, so it won't freeze 4D even on a large database, but it can still take a while.

### Example
```4d
ARRAY TEXT($uids; 0)
ARRAY TEXT($firstNames; 0)
ARRAY TEXT($lastNames; 0)
ARRAY TEXT($orgs; 0)
ARRAY BOOLEAN($firstFirst; 0)
ARRAY BOOLEAN($asCompany; 0)
ARRAY TEXT($modDates; 0)
ARRAY REAL($modStamps; 0)

AB LIST GROUP PEOPLE(""; $uids; $firstNames; $lastNames; $orgs; $firstFirst; $asCompany; $modDates; $modStamps)
```

---

## AB FIND PEOPLE

### Syntax
```4d
AB FIND PEOPLE ( properties ; labels ; keys ; values ; comparisons ; matchAll ; results )
```

| Parameter | Type | Description |
|---|---|---|
| `properties` | Text array | One property name per criterion (see the name list under [`AB QUERY PEOPLE`](#ab-query-people); same IM-property search gap applies) |
| `labels` | Text array | One label filter per criterion (`""` = any label) |
| `keys` | Text array | One sub-key per criterion, only meaningful for `Address` entries (`""` otherwise) |
| `values` | Text array | One comparison value per criterion |
| `comparisons` | Text array | One comparison name per criterion (see the name list under [`AB QUERY PEOPLE`](#ab-query-people)) |
| `matchAll` | Longint | `0` = OR the criteria together (match any one), any other value = AND them together (match all) |
| `results` | Text array | (by reference) Receives every matching person's unique ID |

This command has no function result — matches are reported through `results` only. `properties`, `labels`, `keys`, `values`, and `comparisons` must all be the same size, or the command does nothing at all (no error, no result) — array index `1` is skipped entirely (indexing for all five arrays starts at `2` internally), so build these starting from index `2`, not `1`, if you're populating them by hand.

### Description
Runs several [`AB QUERY PEOPLE`](#ab-query-people)-style criteria combined with a single AND/OR conjunction (not per-pair conjunctions).

### Example
```4d
ARRAY TEXT($properties; 3)
ARRAY TEXT($labels; 3)
ARRAY TEXT($keys; 3)
ARRAY TEXT($values; 3)
ARRAY TEXT($comparisons; 3)
$properties{2}:=AB LastName; $labels{2}:=""; $keys{2}:=""; $values{2}:="Yamashita"; $comparisons{2}:=AB Equal
$properties{3}:=AB Organization; $labels{3}:=""; $keys{3}:=""; $values{3}:="4D"; $comparisons{3}:=AB ContainsSubString

ARRAY TEXT($results; 0)
AB FIND PEOPLE($properties; $labels; $keys; $values; $comparisons; 1; $results)  //AND
```

---

## AB GET GROUP GROUPS

### Syntax
```4d
AB GET GROUP GROUPS ( uniqueId ; groups )
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Group's unique ID |
| `groups` | Text array | (by reference) Receives the unique ID of every group this group directly belongs to |
| Result | — | No function result |

### Description
Same relationship (parent groups) as [`AB Get parent groups`](#ab-get-parent-groups), but as a bare array-out command with no status flag rather than a `Longint` result. `groups` is always written (cleared to size `0` if there are no parent groups), unlike [`AB Get groups in group`](#ab-get-groups-in-group).

### Example
```4d
ARRAY TEXT($parents; 0)
AB GET GROUP GROUPS($groupUID; $parents)
```

---

## AB GET PERSON GROUPS

### Syntax
```4d
AB GET PERSON GROUPS ( uniqueId ; groups )
```

| Parameter | Type | Description |
|---|---|---|
| `uniqueId` | Text | Person's unique ID |
| `groups` | Text array | (by reference) Receives the unique ID of every group this person directly belongs to |
| Result | — | No function result |

### Example
```4d
ARRAY TEXT($groups; 0)
AB GET PERSON GROUPS($personUID; $groups)
```

---

## AB REMOVE FROM PRIVACY LIST

### Syntax
```4d
AB REMOVE FROM PRIVACY LIST
```

No parameters, no result.

### Description
Resets your app's Contacts privacy authorization (via `/usr/bin/tccutil reset AddressBook`) so the system permission prompt will be shown again the next time [`AB Request permisson`](#ab-request-permisson) is called. Useful during development/testing when you need to re-trigger the prompt; not something to call routinely in a shipped app, since it also wipes out any previously granted permission for every app that shares that TCC bucket, not just yours.

### Example
From the plugin's own test method (`Method2.4dm`, guarded so it isn't run unintentionally):
```4d
If (False)
	AB REMOVE FROM PRIVACY LIST
End if
```

---

## AB Request permisson

### Syntax
```4d
AB Request permisson
```

| Parameter | Type | Description |
|---|---|---|
| Result | Longint | See the status codes below |

### Description
Call this once before any other command in this plugin. It performs three checks, each of which can short-circuit with its own code:

| Result | Meaning |
|---|---|
| `1` | Permission is granted (either already, or just now) |
| `0` | Permission request is pending, denied, or restricted — see note below |
| `-1` | The `com.apple.security.personal-information.addressbook` entitlement is present but set to disabled |
| `-2` | The entitlement is missing entirely from your app's code signature |
| `-3` | `NSContactsUsageDescription` is missing from your app's `Info.plist` |
| `-4` | Couldn't read your app's `Info.plist` at all |
| `-5` | Couldn't locate the app's main bundle |

**The permission grant itself is asynchronous.** The very first time a freshly installed app calls this command, macOS shows the system permission dialog and answers asynchronously — this command can return `0` immediately, before the user has even seen or answered that dialog, regardless of what they choose. If you get `0` on a first run, don't treat it as a hard denial: give the user a moment (or wait for your own retry/next app launch) and call it again before concluding access was refused.

### Example
From the plugin's own test methods (`Method4.4dm`, `CB_TEST.4dm`, `issue_2.4dm`):
```4d
$permisson:=AB Request permisson
```

Checking the specific failure reason:
```4d
Case of
	: ($permisson=1)
		//proceed
	: ($permisson=-2) | ($permisson=-1)
		ALERT("Add the com.apple.security.personal-information.addressbook entitlement.")
	: ($permisson=-3)
		ALERT("Add NSContactsUsageDescription to Info.plist.")
	Else
		ALERT("Contacts access isn't available yet — try again in a moment.")
End case
```

---

## Error handling & troubleshooting

- **Call `AB Request permisson` first, every time, in every app that embeds this plugin.** Nothing else raises a 4D error for a permissions problem — every other command just quietly returns `0`/empty, which looks identical to "record not found."
- **A `0`/empty result almost never means an error was thrown.** Malformed or unrecognized unique IDs, unrecognized property/label/comparison names, and permission problems are all reported the same way: a plain `0` (or empty text/array), with detail only in the plugin's internal `NSLog` output (Console.app), which 4D itself never sees. Don't rely on 4D's own error-trapping (`ON ERR CALL`) to catch problems from this plugin.
- **A "success" `Longint` result of `1` means the local change was accepted; it doesn't guarantee the save to disk succeeded cleanly.** When Apple's own `saveAndReturnError:` step fails, the command instead returns that raw `NSError` code — treat anything other than exactly `1` as "something didn't fully go through," not as a plain boolean.
- **The five instant-messaging property names don't work as search criteria.** `AIMInstant`, `JabberInstant`, `MSNInstant`, `YahooInstant`, `ICQInstant` are fully supported by [`AB Set person properties`](#ab-set-person-properties)/[`AB Get person properties`](#ab-get-person-properties), but [`AB QUERY PEOPLE`](#ab-query-people)/[`AB FIND PEOPLE`](#ab-find-people) can't find matches on them — there's no current workaround short of reading every candidate person's properties directly and comparing yourself.
- **`AB Get groups in group` and `AB Get parent groups` don't clear their output array when there's no match** — only [`AB Get people in group`](#ab-get-people-in-group) and [`AB GET GROUP GROUPS`](#ab-get-group-groups) always do. Clear the array yourself immediately before the call if you can't guarantee it's already empty.
- **`AB Set me` reports success even for an ID that doesn't resolve** — it silently clears the "me" designation instead. Verify with [`AB Get me`](#ab-get-me) after the call if the outcome matters.
- **First-run permission checks can look like a denial when they're really just pending.** See the asynchronous-grant note under [`AB Request permisson`](#ab-request-permisson).
- **`AB Set notification method` is not safe to call from multiple processes concurrently.** Register it once, from a single, consistent place (e.g. your database's `On Startup` method), not per-process or per-window.

---

## Quick reference

```4d
// One-time setup
$permisson:=AB Request permisson
AB Set notification method("ADDRESS_BOOK_CHANGED")

// Create + fill in a person
$p:=AB Create person()
AB Set person property($p; AB FirstName; "Taro")
AB Set person property($p; AB LastName; "Yamada")
AB Set person property($p; AB Note; "Met at conference")

ARRAY TEXT($labels; 1)
ARRAY TEXT($emails; 1)
$labels{1}:="work"
$emails{1}:="taro@example.com"
AB Set person properties($p; AB Email; $labels; $emails)

// Search
ARRAY TEXT($results; 0)
AB QUERY PEOPLE(AB LastName; ""; ""; "Yamada"; AB Equal; $results)

// Groups
$g:=AB Create group()
AB Set group name($g; "Conference contacts")
If (Size of array($results)>0)
	AB Add person to group($g; $results{1})
End if

// Bulk export
ARRAY TEXT($allIds; 0)
AB GET LIST(AB People; $allIds; AB RecordsAll)
```
