//
//  MWKSavedPageEntry+Random.m
//  Wikipedia
//
//  Created by Brian Gerstle on 10/15/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

#import "MWKSavedPageEntry+Random.h"
#import "MWKSavedPageEntry+ImageMigration.h"
#import "MWKTitle+Random.h"

@implementation MWKSavedPageEntry (Random)

+ (instancetype)random {
    MWKSavedPageEntry* entry = [[MWKSavedPageEntry alloc] initWithTitle:[MWKTitle random]];
    entry.didMigrateImageData = arc4random() % 2 == 0;
    return entry;
}

@end
