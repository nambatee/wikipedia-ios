
#import "PiwikTracker+WMFExtensions.h"
#import "MWKTitle+WMFAnalyticsLogging.h"

NS_ASSUME_NONNULL_BEGIN

static NSString* const WMFPiwikServerURL = @"http://piwik.wmflabs.org/";
static NSString* const WMFPiwikSiteID    = @"4";

@implementation PiwikTracker (WMFExtensions)

+ (void)wmf_start {
#if PIWIK_ENABLED
    [PiwikTracker sharedInstanceWithSiteID:WMFPiwikSiteID baseURL:[NSURL URLWithString:WMFPiwikServerURL]];
#endif
}

- (void)wmf_logView:(id<WMFAnalyticsLogging>)view {
    [self sendView:[view analyticsName]];
}

- (void)wmf_logViewForTitle:(MWKTitle*)title fromSource:(nullable id<WMFAnalyticsLogging>)source {
    if (source) {
        [self sendViewsFromArray:@[[source analyticsName], @"Article", [title analyticsName]]];
    } else {
        [self sendViewsFromArray:@[@"Article", [title analyticsName]]];
    }
}

- (void)wmf_logActionPreviewForTitle:(MWKTitle*)title fromSource:(nullable id<WMFAnalyticsLogging>)source {
    [self sendEventWithCategory:@"Preview" action:@"Shown" name:[source analyticsName] value:nil];
}

- (void)wmf_logActionPreviewDismissedForTitle:(MWKTitle*)title fromSource:(nullable id<WMFAnalyticsLogging>)source{
    [self sendEventWithCategory:@"Preview" action:@"Dismissed" name:[source analyticsName] value:nil];
}

- (void)wmf_logActionPreviewCommittedForTitle:(MWKTitle*)title fromSource:(nullable id<WMFAnalyticsLogging>)source{
    [self sendEventWithCategory:@"Preview" action:@"Converted" name:[source analyticsName] value:nil];
}

- (void)wmf_logActionSaveTitle:(MWKTitle*)title fromSource:(nullable id<WMFAnalyticsLogging>)source {
    [self sendEventWithCategory:@"Save" action:@"Save" name:[source analyticsName] value:nil];
}

- (void)wmf_logActionUnsaveTitle:(MWKTitle*)title fromSource:(nullable id<WMFAnalyticsLogging>)source {
    [self sendEventWithCategory:@"Save" action:@"Unsave" name:[source analyticsName] value:nil];
}

- (void)wmf_logActionScrollToHomeSection:(id<WMFAnalyticsLogging>)section {
    [self sendEventWithCategory:@"Home" action:@"Scroll To Section" name:[section analyticsName] value:nil];
}

- (void)wmf_logActionOpenMoreForHomeSection:(id<WMFAnalyticsLogging>)section {
    [self sendEventWithCategory:@"Home" action:@"Open More Like" name:[section analyticsName] value:nil];
}

@end

NS_ASSUME_NONNULL_END