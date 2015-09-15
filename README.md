4d-pugin-address-book
=====================

4D Plugin to access the contacts database on OS X, using the old AddressBook framework.

Change list for 2015-09-16

Added 64 bits, v14 architecture.

Important: The callback system has been revised; now the process name is a UUID. Previously it was "AddressBook Notification".

```
Change list for 2012-05-19

New Commands

AB Is access denied

AB REMOVE FROM PRIVACY LIST

AB GET GROUP GROUPS

AB GET PERSON GROUPS

Change list for 2012-03-23

New Commands

AB FIND PEOPLE

Change list for 2011-11-21

Several mistakes in the mask constants are corrected. Added utility method AB LIST GROUP PEOPLE.

Change list for 2011-10-31

AB Get person property now accepts AB CreateDate and AB ModificationDate.

Change list for 2011-10-18

The project is now linked to the 10.5 SDK; the previous version required 10.6 or later. More specifically, instead of using NSRunningApplication for AB_TERMINATE, it now uses AppleScript.

New Commands

AB Set notification method

AB Get notification method

AB Get_default country code

AB Get_default name_ordering

AB Get parent groups

Important Notice:

The plugin ID has been changed from 10015 to 20000.

According to current specification, the constant ID of a plugin with an ID of 10000 for theme 1, 2… is 10000, 10001,.. and so on. This means that the ID of constants others than the primary theme can possibly clash with constants of another plugin.

To avoid such conflict, the ID of certain plugins may mauve to be adjusted.

This may have negative effect on existing code (4D methods) that are tokenized using the previous version. Users are advised to preserve the textual content of the method before replacing the plugin with a later version.

Application

AB LAUNCH
AB LAUNCH

Discussion

This command launches the Address Book application.

AB TERMINATE
AB TERMINATE

Discussion

This command terminates the Address Book application.

People

AB Create person
person:=AB Create person

person (TEXT)

The record UUID of the newly created person record.

Discussion

This command creates a new person record.

AB Create person with vcard
person:=AB Create person with vcard (vcard)

vcard (TEXT)

The vcard record.

person (TEXT)

The record UUID of the newly created person record.

Discussion

This command creates a new person record from a vcard representation.

AB Get me
person:=AB Get me

person (TEXT)

The person ID of the person set as me.

Discussion

This command returns the ID of record marked as me.

AB Get person flags
success:=AB Get person flags (person; flags)

person (TEXT)

The person record UUID.

flags (LONGINT)

The flags of this person record.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command gets the flags of a person record.

AB Get person image
success:=AB Get person image (person; image)

person (TEXT)

The person record UUID.

image (PICTURE)

The picture of this person record.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command gets the picture of a person record.

AB Get person properties
LONGINT:=AB Get person properties (person; property; key; value)

person (TEXT)

The person record UUID.

property (TEXT)

The property name.

key (ARRAY)

An array of label names.

value (ARRAY)

An array of label values.

returnValue (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command gets the multi value property of a person.

AB Get person property
success:=AB Get person property (person; property; value)

person (TEXT)

The person record UUID.

property (TEXT)

The property name.

value (TEXT)

The property value. Date value is represented in XML format.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command gets the specified property value of a person record.

AB Person get vcard
success:=AB Person get vcard (person; vcard)

person (TEXT)

The record UUID of the newly created person record.

vcard (TEXT)

The vcard representation of this person record.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command gets the vcard representation of a person record.

AB QUERY PEOPLE
AB QUERY PEOPLE (property; label; key; value; comparison; people)

property (TEXT)

The property name to query.

label (TEXT)

The property label to query.

key (TEXT)

The property key to query. Certain properties have keys, the address for example.

value (TEXT)

The property value to compare against.

comparison (TEXT)

The type of comparison to perform.

people (ARRAY)

Text array of person record UUIDs found.

Discussion

This command searches the data store for person records that meet the specified criteria.

AB Remove person
success:=AB Remove person (person)

person (TEXT)

The person record UUID.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command removes the specified person record from the data store.

AB Set me
success:=AB Set me (person)

person (TEXT)

The person Id of the rocrd to set as me.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command sets a person as me. if an invalid ID is passed, there wil be no record set as me.

AB Set person flags
success:=AB Set person flags (person; flags)

person (TEXT)

The person record UUID.

flags (LONGINT)

The new flags of this person record.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command sets the flags of a person record.

AB Set person image
success:=AB Set person image (person; image)

person (TEXT)

The person record UUID.

image (PICTURE)

The picture to set for this person record.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command sets the picture of a person record.

The picture should be supplied in png, pdf, jpg or tiff format.

AB Set person properties
LONGINT:=AB Set person properties (person; property; key; value)

person (TEXT)

The person record UUID.

property (TEXT)

The property name.

key (ARRAY)

An array of label names.

value (ARRAY)

An array of label values.

returnValue (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command sets the multi value property of a person. The first element will become the primary identifier.

AB Set person property
success:=AB Set person property (person; property; value)

person (TEXT)

The person record UUID.

property (TEXT)

The property name.

value (TEXT)

The property value to set. Date value should be represented in text format.

Use the utility command AB Make date to composite date, time and timezone.

success (LONGINT)

Returns 1 if successful, otherwise 0 or an error code.

Discussion

This command sets the specified property value of a person record.

Group

AB Add group to group
success:=AB Add group to group (group; subgroup)

group (TEXT)

The record UUID of the group to which the other group should be added.

subgroup (TEXT)

The record UUID of the group which should be contained in the other group.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command adds the specifed group record to the specifed group.

AB Add person to group
success:=AB Add person to group (group; person)

group (TEXT)

The record UUID of the group to which the person should be added.

person (TEXT)

The record UUID of the person which should be contained in the group.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command adds the specifed person record to the specifed group.

AB Create group
group:=AB Create group

group (TEXT)

The record UUID of the newly created group record.

Discussion

This command creates a new group record.

AB Get group name
success:=AB Get group name (group; name)

group (TEXT)

The group record UUID.

name (TEXT)

The name of this group.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command gets the name of a group record.

AB Get groups in group
success:=AB Get groups in group (group; groups)

group (TEXT)

The group record UUID.

groups (ARRAY)

Text array of group record UUIDs.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command gets all the group records in the specified group.

AB Get people in group
success:=AB Get people in group (group; people)

group (TEXT)

The group record UUID.

people (ARRAY)

Text array of person record UUIDs.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command gets all the person records in the specified group.

AB Remove group
success:=AB Remove group (group)

group (TEXT)

The group record UUID.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command removes the specifed group record from the data store.

AB Remove group from group
success:=AB Remove group from group (group; subgroup)

group (TEXT)

The record UUID of the group which contains the other group.

subgroup (TEXT)

The record UUID of the group which should be removed from the other group.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command removes the specifed group record from the specifed group.

AB Remove person from group
success:=AB Remove person from group (group; person)

group (TEXT)

The group record UUID.

person (TEXT)

The person record UUID.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command removes the specifed person record from the specifed group.

AB Set group name
success:=AB Set group name (group; name)

group (TEXT)

The group record UUID.

name (TEXT)

The name to set for this group.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command sets the name of a group record.

Type Cast

AB GET ADDRESS
AB GET ADDRESS (address; street; city; state; zip; country; countryCode)

address (TEXT)

The XML representation of an address record.

street (TEXT)

Value of the Street field.

city (TEXT)

Value of the City field.

state (TEXT)

Value of the State field.

zip (TEXT)

Value of the ZIP field.

country (TEXT)

Value of the Country field.

countryCode (TEXT)

Value of the CountryCode field.

Discussion

This command extracts text values from an XML representation of an address record.

AB GET DATE
AB GET DATE (date; day; time; offset)

date (TEXT)

The XML representation of a date record.

day (DATE)

The date.

time (TIME)

The time.

offset (LONGINT)

The timezone offset from GMT in seconds.

Discussion

This command extracts text values from an XML representation of a date record.

AB Make address
address:=AB Make address (street; city; state; zip; country; countryCode)

street (TEXT)

Value of the Street field.

city (TEXT)

Value of the City field.

state (TEXT)

Value of the State field.

zip (TEXT)

Value of the ZIP field.

country (TEXT)

Value of the Country field.

countryCode (TEXT)

Value of the CountryCode field.

See country code list for valid values.

address (TEXT)

The XML representation of an address record.

Discussion

This command converts text values to an XML representation of an address record.

AB Make date
date:=AB Make date (day; time; timezone)

day (DATE)

The date.

time (TIME)

The time.

timezone (TEXT)

The timezone.

date (TEXT)

The XML representation of a date record.

Discussion

This command converts date, time and timezone information to an XML representation of a date record.

Address Book

AB GET LIST
AB GET LIST (recordType; IDs; condition; date)

recordType (LONGINT)

The type of records to retrieve.

IDs (ARRAY)

An array of record IDs.

condition (LONGINT)

A query consition of the list to fetch.

date (TEXT)

The anchor date.

Discussion

This command returns the UUIDs of records in the data store.

Utilities

AB Get default country code
countryCode:=AB Get default country code

countryCode (TEXT)

The country code.

See country code list for valid values.

Discussion

AB Get default name ordering
ordering:=AB Get default name ordering

ordering (LONGINT)

AB FirstNameFirst or AB LastNameFirst.

Discussion

AB Get localized string
localized:=AB Get localized string (string)

string (TEXT)

The non-localized label or property name.

localized (TEXT)

The localized string for this label or property.

Discussion

The localized string for this label or property.

Notification

AB Get notification method
success:=AB Get notification method (method)

method (TEXT)

The method name.

success (LONGINT)

1 for success, 0 for failure.

Discussion

This command returns the method name installed as the event handler for every addressbook update event.

AB Set notification method
success:=AB Set notification method (method)

method (TEXT)

The method name.

success (LONGINT)

1 for success, 0 for failure.

Discussion

This command installs an event handler to be invoked for every addressbook update event.

The event handler receives 3 text aruguments, each containing lines of inserted record IDs, updated record IDs and deleted record IDs respectively.

Group II

AB Get parent groups
success:=AB Get parent groups (group; groups)

group (TEXT)

The group record UUID.

groups (ARRAY)

Text array of group record UUIDs.

success (LONGINT)

Returns 1 if successful, otherwise 0.

Discussion

This command gets all the parent group records of the specified group.

Special

AB FIND PEOPLE
AB FIND PEOPLE (properties; labels; keys; values; comparisons; conjunction; people)

properties (ARRAY)

The property names to query.

labels (ARRAY)

The property labels to query.

You can use a AB All Properties constant for labels.

keys (ARRAY)

The property keys to query. Certain properties have keys, the address for example.

You can use a AB Labels constant for keys.

values (ARRAY)

The property values to compare against.

You can use a AB Address Keys constant for values.

comparisons (ARRAY)

The type of comparison to perform.

You can use a AB Comparison Options constant for comparisons.

conjunction (LONGINT)

The type of conjunction to be applied to the set of conditions.

You can use a AB Conjunction constant for conjunction.

people (ARRAY)

Text array of person record UUIDs found.

Discussion

This command searches the data store for person records that meet the specified multiple criteria.

AB GET GROUP GROUPS
AB GET GROUP GROUPS (group; groups)

group (TEXT)

Group UID.

groups (ARRAY)

The groups UIDs. (ARRAY TEXT)

Discussion

Get the parent groups to which the group belongs.

AB GET PERSON GROUPS
AB GET PERSON GROUPS (person; groups)

person (TEXT)

Person UID.

groups (ARRAY)

The groups UIDs. (ARRAY TEXT)

Discussion

Get the parent groups to which the person belongs.

AB Is access denied
LONGINT:=AB Is access denied

returnValue (LONGINT)

Discussion

AB LIST GROUP PEOPLE
AB LIST GROUP PEOPLE (group; person; firstName; lastName; organization; firstNameFirst; showAsCompany; modifyDate; modifyDateAbosolute)

group (TEXT)

The group ID.

person (ARRAY)

The person ID.

firstName (ARRAY)

The first name. (ARRAY TEXT)

lastName (ARRAY)

The last name. (ARRAY TEXT)

organization (ARRAY)

The company name. (ARRAY TEXT)

firstNameFirst (ARRAY)

Whether the record should show first name first. (ARRAY BOOLEAN).

showAsCompany (ARRAY)

Whether the record should show as a company. (ARRAY BOOLEAN).

modifyDate (ARRAY)

The modification date. (ARRAY TEXT).

modifyDateAbosolute (ARRAY)

The modification date, expressed in UNIX time (ARRAY REAL).

Discussion

This command allows one to retrive basic information about all the people who belongs to a group in one call.

AB REMOVE FROM PRIVACY LIST
AB REMOVE FROM PRIVACY LIST

Discussion

AB Labels

AB WorkLabel (_$!<Work>!$_)

AB HomeLabel (_$!<Home>!$_)

AB AnniversaryLabel (_$!<Anniversary>!$_)

AB FatherLabel (_$!<Father>!$_)

AB MotherLabel (_$!<Mother>!$_)

AB ParentLabel (_$!<Parent>!$_)

AB BrotherLabel (_$!<Brother>!$_)

AB SisterLabel (_$!<Sister>!$_)

AB ChildLabel (_$!<Child>!$_)

AB FriendLabel (_$!<Friend>!$_)

AB SpouseLabel (_$!<Spouse>!$_)

AB PartnerLabel (_$!<Partner>!$_)

AB AssistantLabel (_$!<Assistant>!$_)

AB ManagerLabel (_$!<Manager>!$_)

AB iPhoneLabel (iPhone)

AB MobileLabel (_$!<Mobile>!$_)

AB MainLabel (_$!<Main>!$_)

AB HomeFAXLabel (_$!<HomeFAX>!$_)

AB WorkFAXLabel (_$!<WorkFAX>!$_)

AB PagerLabel (_$!<Pager>!$_)

AB OtherLabel (_$!<Other>!$_)

AB Properties

AB FirstName (FirstName)

AB LastName (LastName)

AB FirstNamePhonetic (FirstNamePhonetic)

AB LastNamePhonetic (LastNamePhonetic)

AB Nickname (Nickname)

AB MaidenName (MaidenName)

AB Birthday (Birthday)

AB Organization (Organization)

AB JobTitle (JobTitle)

AB Note (Note)

AB Department (Department)

AB MiddleName (MiddleName)

AB MiddleNamePhonetic (MiddleNamePhonetic)

AB Title (Title)

AB Suffix (Suffix)

AB CreationDate (CreationDate)

AB ModificationDate (ModificationDate)

AB Multi Value Properties

AB URLs (URLs)

AB CalendarURI (CalendarURI)

AB Email (Email)

AB Address (Address)

AB OtherDates (OtherDates)

AB RelatedNames (RelatedNames)

AB Phone (Phone)

AB AIMInstant (AIMInstant)

AB JabberInstant (JabberInstant)

AB MSNInstant (MSNInstant)

AB YahooInstant (YahooInstant)

AB ICQInstant (ICQInstant)

AB Comparison Options

AB Equal (Equal)

AB NotEqual (NotEqual)

AB DoesNotContainSubString (DoesNotContainSubString)

AB PrefixMatch (PrefixMatch)

AB ContainsSubString (ContainsSubString)

AB SuffixMatch (SuffixMatch)

AB Flags

AB ShowAsPerson (0)

AB DefaultNameOrdering (0)

AB ShowAsCompany (1)

AB ShowAsResource (2)

AB ShowAsRoom (3)

AB ShowAsMask (7)

AB LastNameFirst (32)

AB FirstNameFirst (64)

AB NameOrderingMask (112)

AB Address Keys

AB CountryCode (CountryCode)

AB Country (Country)

AB ZIP (ZIP)

AB State (State)

AB City (City)

AB Street (Street)

AB All Properties

AB ModificationDate (ModificationDate)

AB CreationDate (CreationDate)

AB UID (UID)

AB ICQInstant (ICQInstant)

AB YahooInstant (YahooInstant)

AB MSNInstant (MSNInstant)

AB JabberInstant (JabberInstant)

AB AIMInstant (AIMInstant)

AB Phone (Phone)

AB RelatedNames (RelatedNames)

AB OtherDates (OtherDates)

AB Address (Address)

AB Email (Email)

AB CalendarURI (CalendarURI)

AB URLs (URLs)

AB Suffix (Suffix)

AB Title (Title)

AB MiddleNamePhonetic (MiddleNamePhonetic)

AB MiddleName (MiddleName)

AB Department (Department)

AB Note (Note)

AB JobTitle (JobTitle)

AB Organization (Organization)

AB Birthday (Birthday)

AB MaidenName (MaidenName)

AB Nickname (Nickname)

AB LastNamePhonetic (LastNamePhonetic)

AB FirstNamePhonetic (FirstNamePhonetic)

AB LastName (LastName)

AB FirstName (FirstName)

AB List Type

AB RecordsAll (0)

AB RecordsCreatedSince (1)

AB RecordsModifiedSince (2)

AB Record Type

AB People (0)

AB Groups (1)

AB Conjunction

AB Or (0)

AB And (1)
```
