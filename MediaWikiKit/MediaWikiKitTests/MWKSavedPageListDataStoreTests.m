//
//  MWKSavedPageListDataStoreTests.m
//  Wikipedia
//
//  Created by Brian Gerstle on 10/14/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

#import "MWKDataStoreListTests.h"
#import "MWKSavedPageEntry+ImageMigration.h"

@interface MWKSavedPageListDataStoreTests : MWKDataStoreListTests

@end

@implementation MWKSavedPageListDataStoreTests

+ (Class)listClass {
    return [MWKSavedPageList class];
}

+ (id)uniqueListEntry {
    static BOOL migrated = NO;
    migrated ^= YES;
    MWKSavedPageEntry* entry = [[MWKSavedPageEntry alloc] initWithTitle:[MWKTitle random]];
    entry.didMigrateImageData = migrated;
    return entry;
}

@end
