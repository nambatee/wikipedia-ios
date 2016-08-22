@import UIKit;

@class MWKArticle;

@interface WMFURLCache : NSURLCache

- (void)permanentlyCacheImagesForArticle:(MWKArticle *)article;

- (UIImage *)cachedImageForURL:(NSURL *)url;

@end
