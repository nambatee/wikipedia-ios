#import "WMFContentGroup+Extensions.h"

NS_ASSUME_NONNULL_BEGIN

@interface WMFContentGroupDataStore : NSObject

- (instancetype)initWithDataStore:(MWKDataStore *)dataStore;

#pragma mark - Content Group Access

- (nullable WMFContentGroup *)contentGroupForURL:(NSURL *)url inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (void)enumerateContentGroupsOfKind:(WMFContentGroupKind)kind inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext withBlock:(void (^)(WMFContentGroup *_Nonnull group, BOOL *stop))block;

- (nullable WMFContentGroup *)firstGroupOfKind:(WMFContentGroupKind)kind  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (nullable WMFContentGroup *)firstGroupOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (nullable WMFContentGroup *)firstGroupOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date siteURL:(NSURL *)url  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (nullable NSArray<WMFContentGroup *> *)groupsOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;


#pragma mark - Content Management

- (nullable WMFContentGroup *)fetchOrCreateGroupForURL:(NSURL *)URL ofKind:(WMFContentGroupKind)kind forDate:(NSDate *)date withSiteURL:(nullable NSURL *)siteURL associatedContent:(nullable NSArray<NSCoding> *)associatedContent inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext withCustomizationBlock:(nullable void (^)(WMFContentGroup *group))customizationBlock;

- (nullable WMFContentGroup *)createGroupOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date withSiteURL:(nullable NSURL *)siteURL associatedContent:(nullable NSArray<NSCoding> *)associatedContent inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (nullable WMFContentGroup *)createGroupOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date withSiteURL:(nullable NSURL *)siteURL associatedContent:(nullable NSArray<NSCoding> *)associatedContent inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext withCustomizationBlock:(nullable void (^)(WMFContentGroup *group))customizationBlock;

- (void)removeContentGroup:(WMFContentGroup *)group fromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (void)removeContentGroupsWithKeys:(NSArray<NSString *> *)keys fromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (void)removeAllContentGroupsOfKind:(WMFContentGroupKind)kind fromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end

NS_ASSUME_NONNULL_END
