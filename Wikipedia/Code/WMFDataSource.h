#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol WMFDataSourceObserver;

typedef void (^ WMFDataSourceObserverHandler)(id <WMFDataSourceObserver> observer);

@interface WMFDataSource : NSObject

- (void)addObserver:(id <WMFDataSourceObserver>)observer;
- (void)removeObserver:(id <WMFDataSourceObserver>)observer;

- (void)enumerateObserversUsingBlock:(WMFDataSourceObserverHandler)handler;

- (void)didChangeContent; //subclassers should call this to trigger dataSourceDidChangeContent: on observers

- (NSInteger)numberOfItemsInSection:(NSInteger)section;


@property (nonatomic, readonly) NSInteger numberOfSections;
@property (nonatomic, readonly) NSInteger numberOfItems; // total number of items in all sections

- (nullable id)itemAtIndexPath:(NSIndexPath *)indexPath;

- (void)fetch;

@end


@protocol WMFDataSourceObserver <NSObject>
@required
- (void)dataSourceDidChangeContent:(WMFDataSource*)dataSource;
@end

NS_ASSUME_NONNULL_END