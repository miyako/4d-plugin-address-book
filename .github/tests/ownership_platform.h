/*
 * Force-included before every harness translation unit.
 * Imports the real system headers first (so declarations type-check),
 * then remaps every dangerous platform boundary used by 4DPlugin.cpp to a
 * harness class/function that aborts on use. AddressBook.framework and
 * Contacts.framework are never linked; their classes and constants are
 * provided by deny-by-default stubs in ownership_host.mm.
 */
#ifndef OWNERSHIP_PLATFORM_H
#define OWNERSHIP_PLATFORM_H

#ifdef __OBJC__
#include <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#include <AddressBook/AddressBook.h>
#include <AddressBook/ABAddressBookC.h>
#import <Contacts/Contacts.h>
#include <Security/Security.h>

@interface OwnershipDeniedTask : NSTask @end
@interface OwnershipDeniedWorkspace : NSWorkspace @end
@interface OwnershipDeniedRunningApplication : NSRunningApplication @end
@interface OwnershipDeniedImage : NSImage @end
@interface OwnershipDeniedBundle : NSBundle @end
@interface OwnershipDeniedUUID : NSUUID @end
@interface OwnershipRecordingCenter : NSNotificationCenter @end

#ifdef __cplusplus
extern "C" {
#endif
Class OwnershipDeniedClassFromString(NSString *name);
SecTaskRef OwnershipDeniedSecTaskCreateFromSelf(CFAllocatorRef allocator);
CFTypeRef OwnershipDeniedSecTaskCopyValueForEntitlement(SecTaskRef task, CFStringRef entitlement, CFErrorRef *error);
#ifdef __cplusplus
}
#endif

#ifndef OWNERSHIP_HOST
#define NSTask OwnershipDeniedTask
#define NSWorkspace OwnershipDeniedWorkspace
#define NSRunningApplication OwnershipDeniedRunningApplication
#define NSImage OwnershipDeniedImage
#define NSBundle OwnershipDeniedBundle
#define NSUUID OwnershipDeniedUUID
#define NSNotificationCenter OwnershipRecordingCenter
#define NSClassFromString OwnershipDeniedClassFromString
#define SecTaskCreateFromSelf OwnershipDeniedSecTaskCreateFromSelf
#define SecTaskCopyValueForEntitlement OwnershipDeniedSecTaskCopyValueForEntitlement
#endif
#endif /* __OBJC__ */

#endif
