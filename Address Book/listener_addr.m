#import "listener_addr.h"

@implementation listener_addr

@synthesize insertedRecordsString;
@synthesize updatedRecordsString;
@synthesize deletedRecordsString;

- (void)setNotificationInfo:(NSNotification *)notification
{
	NSArray *insertedRecords	= [[notification userInfo]objectForKey:kABInsertedRecords];
	NSArray *updatedRecords		= [[notification userInfo]objectForKey:kABUpdatedRecords];
	NSArray *deletedRecords		= [[notification userInfo]objectForKey:kABDeletedRecords];	
		
	unsigned int i;
	
	NSMutableString *_insertedRecords = [[NSMutableString alloc]init];
	NSMutableString *_updatedRecords= [[NSMutableString alloc]init];
	NSMutableString *_deletedRecords = [[NSMutableString alloc]init];
	
	if(insertedRecords){
		for(i = 0; i < [insertedRecords count]; i ++){			
			if(!i){
				[_insertedRecords setString:[insertedRecords objectAtIndex:i]];				
			}else{
				[_insertedRecords appendFormat:@"\r%@", [insertedRecords objectAtIndex:i]];
			}			
		}
	}
	
	if(updatedRecords){
		for(i = 0; i < [updatedRecords count]; i ++){
			if(!i){
				[_updatedRecords setString:[updatedRecords objectAtIndex:i]];				
			}else{
				[_updatedRecords appendFormat:@"\r%@", [updatedRecords objectAtIndex:i]];
			}	
		}
	}
	
	if(deletedRecords){
		for(i = 0; i < [deletedRecords count]; i ++){
			if(!i){
				[_deletedRecords setString:[deletedRecords objectAtIndex:i]];				
			}else{
				[_deletedRecords appendFormat:@"\r%@", [deletedRecords objectAtIndex:i]];
			}				
		}
	}
	
	self.insertedRecordsString = _insertedRecords;
	self.updatedRecordsString = _updatedRecords;
	self.deletedRecordsString = _deletedRecords;
	
	[_insertedRecords release];
	[_updatedRecords release];
	[_deletedRecords release];	
}

- (void)addressbookChanged:(NSNotification *)notification
{
	[self setNotificationInfo:notification];
	self.notificationType = @"AddressBook Notification";	
	PA_UnfreezeProcess([self.listenerProcessNumber intValue]);	
}

@end