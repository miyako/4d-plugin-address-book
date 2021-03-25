![version](https://img.shields.io/badge/version-16%2B-8331AE)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-address-book)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-address-book/total)

**Note**: for v17 and earlier, move `manifest.json` to `Contents`

4d-pugin-address-book
=====================

Access "contacts" via the [Address Book API](https://developer.apple.com/library/mac/documentation/UserExperience/Conceptual/AddressBook/AddressBook.html).

To use on v16 or v17, move manifest.json to contents.

**Important Note**: ``AB Is access denied`` has been renamed as ``AB Request permisson``. You must call this once before you use other commands.

You must codesign your app with the following entitlements:

* ``com.apple.security.personal-information.addressbook``

The app must also have the following property list keys:

* ``NSContactsUsageDescription``

See [build-application](https://github.com/miyako/4d-utility-build-application)
