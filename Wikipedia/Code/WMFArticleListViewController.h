
#import <UIKit/UIKit.h>
#import "WMFTitleListDataSource.h"
#import "WMFAnalyticsLogging.h"
#import "WMFDataSourceViewController.h"

@class WMFDataSource, MWKDataStore, WMFArticleListViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol WMFArticleListTableViewControllerDelegate <NSObject>

- (void)listViewController:(WMFArticleListViewController*)listController didSelectArticleURL:(NSURL*)url;

- (UIViewController*)listViewController:(WMFArticleListViewController*)listController viewControllerForPreviewingArticleURL:(NSURL*)url;

- (void)listViewController:(WMFArticleListViewController*)listController didCommitToPreviewedViewController:(UIViewController*)viewController;

@end


@interface WMFArticleListViewController : WMFDataSourceViewController<WMFAnalyticsContextProviding>

@property (nonatomic, strong) MWKDataStore* dataStore;

/**
 *  Optional delegate which will is informed of selection.
 *
 *  If left @c nil, falls back to pushing an article container using its @c navigationController.
 */
@property (nonatomic, weak, nullable) id<WMFArticleListTableViewControllerDelegate> delegate;

@end


@interface WMFArticleListViewController (WMFSubclasses)

- (NSString*)analyticsContext;

- (WMFEmptyViewType)emptyViewType;

- (BOOL)     showsDeleteAllButton;
- (NSString*)deleteButtonText;
- (NSString*)deleteAllConfirmationText;
- (NSString*)deleteText;
- (NSString*)deleteCancelText;

@end

NS_ASSUME_NONNULL_END