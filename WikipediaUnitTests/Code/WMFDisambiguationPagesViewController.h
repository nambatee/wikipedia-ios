#import "WMFArticleListViewController.h"

@interface WMFDisambiguationPagesViewController : WMFArticleListViewController

@property (nonatomic, strong, readonly) MWKArticle* article;

- (instancetype)initWithArticle:(MWKArticle*)article dataStore:(MWKDataStore*)dataStore;

@end
