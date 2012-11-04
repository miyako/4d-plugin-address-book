#import "listener.h"

@implementation listener_class

@synthesize listenerMethodName;
@synthesize listenerMethodId;
@synthesize listenerProcessNumber;

@synthesize notificationType;

- (id)initWithMethodName:(NSString *)methodName methodId:(NSNumber *)methodId processNumber:(NSNumber *)processNumber
{
	if(!(self = [super init]))return self;
	
	self.listenerMethodName = methodName;
	self.listenerMethodId = methodId;	
	self.listenerProcessNumber = processNumber;
	
	shouldTerminate = NO;
	
	return self;
}

- (BOOL)shouldTerminate
{
	return shouldTerminate;	
}

- (void)terminate
{
	shouldTerminate = YES;
	PA_UnfreezeProcess([self.listenerProcessNumber intValue]);		
}

@end