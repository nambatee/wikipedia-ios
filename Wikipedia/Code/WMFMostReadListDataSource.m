
#import "WMFMostReadListDataSource.h"
#import "WMFArticleListTableViewCell.h"
#import "UIView+WMFDefaultNib.h"
#import "UITableViewCell+WMFLayout.h"
#import "MWKSearchResult.h"

@interface WMFMostReadListDataSource ()

@property (nonatomic, copy) NSArray *allItems;
@property (nonatomic, strong) NSURL* siteURL;
@property (nonatomic, strong, readwrite) NSArray<NSURL*>* urls;

@end

@implementation WMFMostReadListDataSource

- (instancetype)initWithPreviews:(NSArray<MWKSearchResult*>*)previews fromSiteURL:(NSURL*)siteURL {
    self = [super init];
    if (self) {
        self.allItems = previews;
        self.siteURL = siteURL;
    }
    return self;
}

#pragma mark - Utils

- (NSURL*)articleURLForPreview:(MWKSearchResult*)preview {
    return [self.siteURL wmf_URLWithTitle:preview.displayTitle];
}

#pragma mark - WMFTitleListDataSource

- (NSURL*)urlForIndexPath:(NSIndexPath*)indexPath {
    return [self articleURLForPreview:[self itemAtIndexPath:indexPath]];
}

- (NSUInteger)titleCount {
    return self.allItems.count;
}

- (BOOL)canDeleteItemAtIndexpath:(NSIndexPath*)indexPath {
    return NO;
}

- (NSArray<NSURL*>*)urls {
    if (!_urls) {
        self.urls = [self.allItems bk_map:^NSURL*(MWKSearchResult* preview) {
            return [self articleURLForPreview:preview];
        }];
    }
    return _urls;
}

@end
