#import "WMFMostReadListTableViewController.h"
#import "WMFMostReadListDataSource.h"
#import "NSDateFormatter+WMFExtensions.h"
#import "WMFArticleListTableViewCell.h"

@implementation WMFMostReadListTableViewController

- (instancetype)initWithPreviews:(NSArray<MWKSearchResult*>*)previews
                     fromSiteURL:(NSURL*)siteURL
                         forDate:date
                       dataStore:(MWKDataStore*)dataStore {
    
    self = [super initWithDataSource:[[WMFMostReadListDataSource alloc] initWithPreviews:previews fromSiteURL:siteURL]];
    if (self) {
        self.dataStore  = dataStore;
        self.title      = [self titleForDate:date];
    }
    return self;
}

- (NSString*)titleForDate:(NSDate*)date {
    return
        [MWLocalizedString(@"explore-most-read-more-list-title-for-date", nil) stringByReplacingOccurrencesOfString:@"$1"
                                                                                                         withString:
         [[NSDateFormatter wmf_utcShortDayNameShortMonthNameDayOfMonthNumberDateFormatter] stringFromDate:date]
        ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
#warning update
//    @strongify(self);
//    NSURL* articleURL = [self urlForIndexPath:indexPath];
//    NSParameterAssert([articleURL.wmf_domainURL isEqual:self.siteURL]);
//    
//    cell.titleText       = articleURL.wmf_title;
//    cell.descriptionText = preview.wikidataDescription;
//    [cell setImageURL:preview.thumbnailURL];
//    
//    [cell wmf_layoutIfNeededIfOperatingSystemVersionLessThan9_0_0];
//
//    [self.tableView registerClass:[WMFArticleListTableViewCell class] forCellReuseIdentifier:@"WMFArticleListTableViewCell"]];
//    
//    [self.tableView registerNib:[WMFArticleListTableViewCell wmf_classNib]
//    forCellReuseIdentifier:[WMFArticleListTableViewCell identifier]];
//    self.tableView.estimatedRowHeight = [WMFArticleListTableViewCell estimatedRowHeight];
    
}

#pragma mark - WMFArticleListTableViewController

- (NSString*)analyticsContext {
    return @"More Most Read";
}

@end
