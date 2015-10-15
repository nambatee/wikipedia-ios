//
//  MWKListBaseTests.m
//  Wikipedia
//
//  Created by Brian Gerstle on 10/14/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

#import "MWKListTestBase.h"

@implementation MWKListDummyEntry

- (instancetype)init {
    self = [super init];
    if (self) {
        self.listIndex = [[NSUUID UUID] UUIDString];
    }
    return self;
}

@end

@implementation MWKListTestBase

- (void)setUp {
    [super setUp];

    NSMutableArray* array = [NSMutableArray array];

    for (int i = 0; i < 10; i++) {
        [array addObject:[[self class] uniqueListEntry]];
    }

    self.testObjects = array;
}

- (void)tearDown {
    self.testObjects = nil;
    [super tearDown];
}

#pragma mark - Testing Data

+ (Class)listClass {
    return [MWKList class];
}

- (MWKList*)listWithEntries:(NSArray*)entries {
    return [[[[self class] listClass] alloc] initWithEntries:entries];
}

+ (id)uniqueListEntry {
    return [[MWKListDummyEntry alloc] init];
}



@end
