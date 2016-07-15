
#import "WMFArticleListViewController.h"
#import "WMFNearbyTitleListDataSource.h"
@import CoreLocation;


@interface WMFLocationSearchListViewController : WMFArticleListViewController

@property (nonatomic, strong, readonly) NSURL* searchDomainURL;
@property (nonatomic, strong) CLLocation* location;

- (instancetype)initWithLocation:(CLLocation*)location searchSiteURL:(NSURL*)url dataStore:(MWKDataStore*)dataStore;

- (instancetype)initWithSearchDomainURL:(NSURL*)url dataStore:(MWKDataStore*)dataStore;

@end
