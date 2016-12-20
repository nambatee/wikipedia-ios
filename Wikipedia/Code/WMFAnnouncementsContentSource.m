#import "WMFAnnouncementsContentSource.h"
#import "WMFAnnouncementsFetcher.h"
#import "WMFAnnouncement.h"
#import "WMFContentGroupDataStore.h"
#import <WMFModel/WMFModel-Swift.h>

@interface WMFAnnouncementsContentSource ()

@property (readwrite, nonatomic, strong) NSURL *siteURL;
@property (readwrite, nonatomic, strong) WMFContentGroupDataStore *contentStore;
@property (readwrite, nonatomic, strong) WMFAnnouncementsFetcher *fetcher;

@end

@implementation WMFAnnouncementsContentSource

- (instancetype)initWithSiteURL:(NSURL *)siteURL contentGroupDataStore:(WMFContentGroupDataStore *)contentStore {
    NSParameterAssert(siteURL);
    NSParameterAssert(contentStore);
    self = [super init];
    if (self) {
        self.siteURL = siteURL;
        self.contentStore = contentStore;
    }
    return self;
}

#pragma mark - Accessors

- (WMFAnnouncementsFetcher *)fetcher {
    if (_fetcher == nil) {
        _fetcher = [[WMFAnnouncementsFetcher alloc] init];
    }
    return _fetcher;
}

- (void)loadNewContentIntoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext completion:(dispatch_block_t)completion {

    [self.fetcher fetchAnnouncementsForURL:self.siteURL
        force:NO
        failure:^(NSError *_Nonnull error) {
            [self updateVisibilityOfAnnouncementsInManagedObjectContext:managedObjectContext];
            if (completion) {
                completion();
            }
        }
        success:^(NSArray<WMFAnnouncement *> *announcements) {
            [announcements enumerateObjectsUsingBlock:^(WMFAnnouncement *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                NSURL *URL = [WMFContentGroup announcementURLForSiteURL:self.siteURL identifier:obj.identifier];
                WMFContentGroup *group = [self.contentStore fetchOrCreateGroupForURL:URL
                                                                              ofKind:WMFContentGroupKindAnnouncement
                                                                             forDate:[NSDate date]
                                                                         withSiteURL:self.siteURL
                                                                   associatedContent:@[obj]
                                          inManagedObjectContext:managedObjectContext withCustomizationBlock:^(WMFContentGroup *_Nonnull group){
                                                                      
                                                                  }];
                //Make these visible immediately for previous users
                if ([[NSUserDefaults wmf_userDefaults] wmf_appResignActiveDate] != nil) {
                    [group updateVisibility];
                }
            }];
            [self updateVisibilityOfAnnouncementsInManagedObjectContext:managedObjectContext];
            if (completion) {
                completion();
            }
        }];
}

- (void)removeAllContentFromManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    [self.contentStore removeAllContentGroupsOfKind:WMFContentGroupKindAnnouncement fromManagedObjectContext:managedObjectContext];
}



- (void)updateVisibilityOfAnnouncementsInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    //Only make these visible for previous users of the app
    //Meaning a new install will only see these after they close the app and reopen
    if ([[NSUserDefaults wmf_userDefaults] wmf_appResignActiveDate] == nil) {
        return;
    }

    [self.contentStore enumerateContentGroupsOfKind:WMFContentGroupKindAnnouncement
     inManagedObjectContext:managedObjectContext
                                          withBlock:^(WMFContentGroup *_Nonnull group, BOOL *_Nonnull stop) {
                                              [group updateVisibility];
                                          }];
}

@end
