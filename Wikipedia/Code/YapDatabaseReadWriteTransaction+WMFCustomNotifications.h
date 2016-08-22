#import <YapDatabase/YapDatabase.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YapDatabaseReadWriteTransaction (WMFCustomNotifications)

- (void)wmf_setUpdatedItemKeys:(nullable NSArray<NSString *> *)keys;

@end

@interface NSNotification (WMFCustomNotifications)

- (nullable NSArray *)wmf_updatedItemKeys;

@end

NS_ASSUME_NONNULL_END
