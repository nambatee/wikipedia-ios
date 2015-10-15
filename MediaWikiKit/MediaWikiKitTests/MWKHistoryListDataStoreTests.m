//
//  MWKHistoryListDataStoreTests.m
//  Wikipedia
//
//  Created by Brian Gerstle on 10/14/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

#import "MWKDataStoreListTests.h"

@interface MWKHistoryListDataStoreTests : MWKDataStoreListTests

@end

@implementation MWKHistoryListDataStoreTests

#pragma mark - MWKListTestBase

+ (id)uniqueListEntry {
    MWKHistoryDiscoveryMethod randomDiscoveryMethod = arc4random() % 7;
    return [[MWKHistoryEntry alloc] initWithTitle:[MWKTitle random]
                                  discoveryMethod:randomDiscoveryMethod];
}

+ (Class)listClass {
    return [MWKHistoryList class];
}

@end
