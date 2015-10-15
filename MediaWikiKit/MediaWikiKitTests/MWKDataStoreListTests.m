//
//  MWKDataStoreListTests.m
//  Wikipedia
//
//  Created by Brian Gerstle on 10/14/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

#import "MWKDataStoreListTests.h"
#import "MWKList+Subclass.h"
#import "MWKDataStore.h"
#import "MWKDataStoreList.h"
#import "MWKDataStore+TemporaryDataStore.h"
#import "WMFAsyncTestCase.h"
#import "XCTestCase+PromiseKit.h"

#import <BlocksKit/BlocksKit.h>

#define HC_SHORTHAND 1
#import <OCHamcrest/OCHamcrest.h>

@implementation MWKDataStoreListTests

- (void)setUp {
    [super setUp];
    self.tempDataStore = [MWKDataStore temporaryDataStore];
}

- (void)tearDown {
    [self.tempDataStore removeFolderAtBasePath];
    [super tearDown];
}

+ (NSArray<NSInvocation*>*)testInvocations {
    return self == [MWKDataStoreListTests class] ? @[] : [super testInvocations];
}

- (MWKList<MWKDataStoreList>*)listWithDataStore {
    Class listClass = [[self class] listClass];
    NSAssert([listClass conformsToProtocol:@protocol(MWKDataStoreList)],
             @"listClass %@ must conform to MWKDataStoreList to run MWKDataStoreListTests.",
             listClass);
    return [[listClass alloc] initWithDataStore:self.tempDataStore];
}

- (void)testAddedEntriesAreIdenticalWhenReadFromDataStore {
    [self verifyListRoundTripAfter:^(MWKList *list) {
        [self.testObjects bk_each:^(id entry) {
            [list addEntry:entry];
        }];
    }];
}

#pragma mark - Utils

- (void)verifyListRoundTripAfter:(void(^)(MWKList*))mutatingBlock {
    MWKList* list = [self listWithDataStore];
    mutatingBlock(list);
    expectResolution(^AnyPromise *{
        return [list save];
    });
    assertThat([self listWithDataStore], is(equalTo(list)));
}

@end
