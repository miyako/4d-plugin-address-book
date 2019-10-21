4d-pugin-address-book
=====================

Access "contacts" via the [Address Book API](https://developer.apple.com/library/mac/documentation/UserExperience/Conceptual/AddressBook/AddressBook.html).

### Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
||<img src="https://cloud.githubusercontent.com/assets/1725068/22371562/1b091f0a-e4db-11e6-8458-8653954a7cce.png" width="24" height="24" />|||

**Important Note**: ``AB Is access denied`` has been renamed as ``AB Request permisson``. You must call this once before you use other commands.

You must codesign your app with the following entitlements:

* ``com.apple.security.personal-information.addressbook``

The app must also have the following property list keys:

* ``NSContactsUsageDescription``

See [build-application](https://github.com/miyako/4d-utility-build-application)
