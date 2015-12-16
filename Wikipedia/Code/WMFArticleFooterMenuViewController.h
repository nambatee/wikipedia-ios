//
//  WMFArticleFooterMenuViewController.h
//  Wikipedia
//
//  Created by Monte Hurd on 12/15/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MWKDataStore;

@interface WMFArticleFooterMenuViewController : UIViewController

@property (nonatomic, strong) MWKDataStore* dataStore;

- (instancetype)initWithArticle:(MWKArticle*)article;

@end
