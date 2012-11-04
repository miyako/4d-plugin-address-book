#import <Cocoa/Cocoa.h>
#import "listener.h"
#include <AddressBook/AddressBook.h>

@interface listener_addr : listener_class
{
	NSString *insertedRecordsString;
	NSString *updatedRecordsString;
	NSString *deletedRecordsString;
}

- (void)setNotificationInfo:(NSNotification *)notification;
- (void)addressbookChanged:(NSNotification *)notification; 

@property (nonatomic, retain) NSString *insertedRecordsString;
@property (nonatomic, retain) NSString *updatedRecordsString;
@property (nonatomic, retain) NSString *deletedRecordsString;

@end
