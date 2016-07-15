#import <UIKit/UIKit.h>
#import "WMFDataSource.h"

@class WMFCell;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSUInteger, WMFDataSourceViewControllerStyle) {
    WMFDataSourceViewControllerStyleTable,
    WMFDataSourceViewControllerStyleCollection
};

@interface WMFDataSourceViewController : UIViewController <WMFDataSourceObserver, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate>

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil dataSource:(WMFDataSource *)dataSource style:(WMFDataSourceViewControllerStyle)style NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithDataSource:(WMFDataSource *)dataSource style:(WMFDataSourceViewControllerStyle)style;
- (instancetype)initWithDataSource:(WMFDataSource *)dataSource;

- (void)configureCell:(WMFCell *)cell forItem:(id)item atIndexPath:(NSIndexPath *)indexPath;

@property (nonatomic, readonly) WMFDataSource *dataSource;
@property (nonatomic, readonly) WMFDataSourceViewControllerStyle style;

@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, readonly) UICollectionView *collectionView;

- (void)reloadCellsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

@end

NS_ASSUME_NONNULL_END