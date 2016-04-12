//
//  QueuesSingleton+AllManagers.h
//  Wikipedia
//
//  Created by Brian Gerstle on 12/11/15.
//

#import "QueuesSingleton.h"

@interface QueuesSingleton (AllManagers)

- (NSArray<AFHTTPSessionManager*>*)allManagers;

@end
