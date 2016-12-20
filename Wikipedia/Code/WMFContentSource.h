#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WMFContentSource <NSObject>

/**
 *  Update now.
 *
 */
- (void)loadNewContentIntoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext completion:(nullable dispatch_block_t)completion;

/**
 * Remove all content from the DB
 */
- (void)removeAllContentFromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end

@protocol WMFAutoUpdatingContentSource <NSObject>

//Start monitoring for content updates
- (void)startUpdating;

//Stop monitoring for content updates
- (void)stopUpdating;

@end

@protocol WMFDateBasedContentSource <NSObject>

/**
 * Load content for a specific date into the DB
 */
- (void)loadContentForDate:(NSDate *)date intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext completion:(nullable dispatch_block_t)completion;

@end

NS_ASSUME_NONNULL_END
