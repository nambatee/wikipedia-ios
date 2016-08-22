@import Foundation;
@import PromiseKit;

@interface WMFZeroMessageFetcher : NSObject

- (AnyPromise *)fetchZeroMessageForSiteURL:(NSURL *)siteURL;

- (void)cancelAllFetches;

@end
