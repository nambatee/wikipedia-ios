@class MWKSearchResult, MWKLocationSearchResult, MWKArticle, WMFFeedArticlePreview, WMFArticle;

NS_ASSUME_NONNULL_BEGIN

@interface WMFArticleDataStore : NSObject

- (instancetype)initWithDataStore:(MWKDataStore *)dataStore;

- (nullable WMFArticle *)itemForURL:(NSURL *)url;

- (nullable WMFArticle *)addPreviewWithURL:(NSURL *)url updatedWithSearchResult:(MWKSearchResult *)searchResult;

- (nullable WMFArticle *)addPreviewWithURL:(NSURL *)url updatedWithLocationSearchResult:(MWKLocationSearchResult *)searchResult;

- (nullable WMFArticle *)addPreviewWithURL:(NSURL *)url updatedWithArticle:(MWKArticle *)article;

- (nullable WMFArticle *)addPreviewWithURL:(NSURL *)url updatedWithFeedPreview:(WMFFeedArticlePreview *)feedPreview pageViews:(nullable NSDictionary<NSDate *, NSNumber *> *)pageViews;

- (void)updatePreview:(WMFArticle *)preview withSearchResult:(MWKSearchResult *)searchResult;

@end

NS_ASSUME_NONNULL_END
