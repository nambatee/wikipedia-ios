
#import "WMFArticleListViewController.h"
#import "WMFSearchDataSource.h"

@interface WMFSearchResultsTableViewController : WMFArticleListViewController

@property (nonatomic, strong) WMFSearchDataSource* dataSource;

@end
