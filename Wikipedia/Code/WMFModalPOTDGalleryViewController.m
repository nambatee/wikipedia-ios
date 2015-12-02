//
//  WMFModalPOTDGalleryViewController.m
//  Wikipedia
//
//  Created by Brian Gerstle on 12/1/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

#import "WMFModalPOTDGalleryViewController.h"
#import "WMFBaseImageGalleryViewController_Subclass.h"
#import "WMFModalImageGalleryViewController_Subclass.h"
#import "WMFModalPOTDGalleryDataSource.h"

@implementation WMFModalPOTDGalleryViewController

- (instancetype)initWithTodaysInfo:(MWKImageInfo*)info {
    self = [super init];
    if (self) {
        self.dataSource = [[WMFModalPOTDGalleryDataSource alloc] initWithTodaysInfo:info];
    }
    return self;
}

@end
