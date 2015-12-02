//
//  WMFImageGalleryDataSource.h
//  Wikipedia
//
//  Created by Brian Gerstle on 12/1/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol WMFImageGalleryDataSource <NSObject>

- (NSURL*)imageURLAtIndexPath:(NSIndexPath*)indexPath;

@end
