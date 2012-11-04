#import <Cocoa/Cocoa.h>

#import "4DPluginAPI.h"

@interface listener_class : NSObject {
	NSString *listenerMethodName;	
	NSNumber *listenerMethodId;	
	NSNumber *listenerProcessNumber;
	NSString *notificationType;	
	BOOL shouldTerminate;
}

- (id)initWithMethodName:(NSString *)methodName methodId:(NSNumber *)methodId processNumber:(NSNumber *)processNumber;

- (BOOL)shouldTerminate;
- (void)terminate;

@property (nonatomic, retain) NSString *listenerMethodName;
@property (nonatomic, retain) NSNumber *listenerMethodId;
@property (nonatomic, retain) NSNumber *listenerProcessNumber;

@property (nonatomic, retain) NSString *notificationType;

@end

void PAListenerRunLoop();
