#import "WMFTitleListDataSource.h"
#import "WMFDataSource.h"

@class MWKSearchResult;

@interface WMFMostReadListDataSource : WMFDataSource
    <WMFTitleListDataSource>

- (instancetype)initWithItems:(NSArray*)items NS_UNAVAILABLE;

- (instancetype)initWithPreviews:(NSArray<MWKSearchResult*>*)previews fromSiteURL:(NSURL*)siteURL;

@end
