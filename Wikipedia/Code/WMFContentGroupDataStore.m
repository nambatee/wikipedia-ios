#import "WMFContentGroupDataStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface WMFContentGroupDataStore ()

@property (nonatomic, strong) MWKDataStore *dataStore;

@end

@implementation WMFContentGroupDataStore

- (instancetype)initWithDataStore:(MWKDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
    }
    return self;
}

#pragma mark - section access

- (NSArray<WMFContentGroup *> *)contentGroupsOfKind:(WMFContentGroupKind)kind inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSFetchRequest *fetchRequest = [WMFContentGroup fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"contentGroupKindInteger == %@", @(kind)];
    NSError *fetchError = nil;
    NSArray *contentGroups = [managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchError || !contentGroups) {
        DDLogError(@"Error fetching content groups: %@", fetchError);
        return @[];
    }
    return contentGroups;
}

- (void)enumerateContentGroupsOfKind:(WMFContentGroupKind)kind inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext withBlock:(void (^)(WMFContentGroup *_Nonnull group, BOOL *stop))block {
    if (!block) {
        return;
    }
    NSArray<WMFContentGroup *> *contentGroups = [self contentGroupsOfKind:kind inManagedObjectContext:managedObjectContext];
    [contentGroups enumerateObjectsUsingBlock:^(WMFContentGroup *_Nonnull section, NSUInteger idx, BOOL *_Nonnull stop) {
        block(section, stop);
    }];
}

- (nullable WMFContentGroup *)contentGroupForURL:(NSURL *)URL inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSParameterAssert(URL);
    if (!URL) {
        return nil;
    }

    NSString *key = [WMFContentGroup databaseKeyForURL:URL];
    if (!key) {
        return nil;
    }

    NSFetchRequest *fetchRequest = [WMFContentGroup fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"key == %@", key];
    fetchRequest.fetchLimit = 1;
    NSError *fetchError = nil;
    NSArray *contentGroups = [managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchError) {
        DDLogError(@"Error fetching content groups: %@", fetchError);
        return nil;
    }
    return [contentGroups firstObject];
}

- (nullable WMFContentGroup *)firstGroupOfKind:(WMFContentGroupKind)kind inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSFetchRequest *fetchRequest = [WMFContentGroup fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"contentGroupKindInteger == %@", @(kind)];
    fetchRequest.fetchLimit = 1;
    NSError *fetchError = nil;
    NSArray *contentGroups = [managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchError) {
        DDLogError(@"Error fetching content groups: %@", fetchError);
        return nil;
    }
    return [contentGroups firstObject];
}

- (nullable WMFContentGroup *)firstGroupOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSFetchRequest *fetchRequest = [WMFContentGroup fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"contentGroupKindInteger == %@ && midnightUTCDate == %@", @(kind), date.wmf_midnightUTCDateFromLocalDate];
    fetchRequest.fetchLimit = 1;
    NSError *fetchError = nil;
    NSArray *contentGroups = [managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchError) {
        DDLogError(@"Error fetching content groups: %@", fetchError);
        return nil;
    }
    return [contentGroups firstObject];
}

- (nullable WMFContentGroup *)firstGroupOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date siteURL:(NSURL*)url  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSFetchRequest *fetchRequest = [WMFContentGroup fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"contentGroupKindInteger == %@ && midnightUTCDate == %@ && siteURLString == %@", @(kind), date.wmf_midnightUTCDateFromLocalDate, url.absoluteString];
    fetchRequest.fetchLimit = 1;
    NSError *fetchError = nil;
    NSArray *contentGroups = [managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchError) {
        DDLogError(@"Error fetching content groups: %@", fetchError);
        return nil;
    }
    return [contentGroups firstObject];
}


- (nullable NSArray<WMFContentGroup *> *)groupsOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSFetchRequest *fetchRequest = [WMFContentGroup fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"contentGroupKindInteger == %@ && midnightUTCDate == %@", @(kind), date.wmf_midnightUTCDateFromLocalDate];
    NSError *fetchError = nil;
    NSArray *contentGroups = [managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchError) {
        DDLogError(@"Error fetching content groups: %@", fetchError);
        return nil;
    }
    return contentGroups;
}

#pragma mark - section add / remove

- (nullable WMFContentGroup *)createGroupOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date withSiteURL:(nullable NSURL *)siteURL associatedContent:(nullable NSArray<NSCoding> *)associatedContent inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext withCustomizationBlock:(nullable void (^)(WMFContentGroup *group))customizationBlock {
    WMFContentGroup *group = [NSEntityDescription insertNewObjectForEntityForName:@"WMFContentGroup" inManagedObjectContext:managedObjectContext];
    group.date = date;
    group.midnightUTCDate = date.wmf_midnightUTCDateFromLocalDate;
    group.contentGroupKind = kind;
    group.siteURLString = siteURL.absoluteString;
    group.content = associatedContent;

    if (customizationBlock) {
        customizationBlock(group);
    }

    [group updateKey];
    [group updateContentType];
    [group updateDailySortPriority];

    return group;
}

- (nullable WMFContentGroup *)fetchOrCreateGroupForURL:(NSURL *)URL ofKind:(WMFContentGroupKind)kind forDate:(NSDate *)date withSiteURL:(nullable NSURL *)siteURL associatedContent:(nullable NSArray<NSCoding> *)associatedContent inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext withCustomizationBlock:(nullable void (^)(WMFContentGroup *group))customizationBlock {

    WMFContentGroup *group = [self contentGroupForURL:URL inManagedObjectContext:managedObjectContext];
    if (group) {
        group.date = date;
        group.midnightUTCDate = date.wmf_midnightUTCDateFromLocalDate;
        group.contentGroupKind = kind;
        group.content = associatedContent;
        group.siteURLString = siteURL.absoluteString;
        if (customizationBlock) {
            customizationBlock(group);
        }
    } else {
        group = [self createGroupOfKind:kind forDate:date withSiteURL:siteURL associatedContent:associatedContent inManagedObjectContext:managedObjectContext withCustomizationBlock:customizationBlock];
    }

    return group;
}

- (nullable WMFContentGroup *)createGroupOfKind:(WMFContentGroupKind)kind forDate:(NSDate *)date withSiteURL:(nullable NSURL *)siteURL associatedContent:(nullable NSArray<NSCoding> *)associatedContent  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    return [self createGroupOfKind:kind forDate:date withSiteURL:siteURL associatedContent:associatedContent inManagedObjectContext:managedObjectContext withCustomizationBlock:NULL];
}

- (void)removeContentGroup:(WMFContentGroup *)group fromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSParameterAssert(group);
    [managedObjectContext deleteObject:group];
}

- (void)removeContentGroups:(NSArray<WMFContentGroup *> *)contentGroups fromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    for (WMFContentGroup *group in contentGroups) {
        [managedObjectContext deleteObject:group];
    }
}

- (void)removeContentGroupsWithKeys:(NSArray<NSString *> *)keys fromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSFetchRequest *request = [WMFContentGroup fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"key IN %@", keys];
    NSError *fetchError = nil;
    NSArray<WMFContentGroup *> *groups = [self.dataStore.viewContext executeFetchRequest:request error:&fetchError];
    if (fetchError) {
        DDLogError(@"Error fetching content groups for deletion: %@", fetchError);
        return;
    }
    [self removeContentGroups:groups fromManagedObjectContext:managedObjectContext];
}

- (void)removeAllContentGroupsOfKind:(WMFContentGroupKind)kind fromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    NSArray *groups = [self contentGroupsOfKind:kind inManagedObjectContext:managedObjectContext];
    [self removeContentGroups:groups fromManagedObjectContext:managedObjectContext];
}

@end

NS_ASSUME_NONNULL_END
