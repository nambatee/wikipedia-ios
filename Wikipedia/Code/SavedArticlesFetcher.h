
#import "FetcherBase.h"

@class MWKArticle,
       MWKSavedPageList,
       WMFArticleFetcher,
       SavedArticlesFetcher,
       WMFImageController;

NS_ASSUME_NONNULL_BEGIN

@interface NSError (SavedArticlesFetcherErrors)

/**
 *  @return Generic error used to indicate one or more images failed to download for the article or its gallery.
 */
+ (instancetype)wmf_savedPageImageDownloadError;

@end

@protocol SavedArticlesFetcherDelegate <FetchFinishedDelegate>

- (void)savedArticlesFetcher:(SavedArticlesFetcher*)savedArticlesFetcher
               didFetchTitle:(MWKTitle*)title
                     article:(MWKArticle* __nullable)article
                    progress:(CGFloat)progress
                       error:(NSError* __nullable)error;

@end

@interface SavedArticlesFetcher : FetcherBase

@property (nonatomic, strong, readonly) MWKSavedPageList* savedPageList;

@property (nonatomic, weak, nullable) id<SavedArticlesFetcherDelegate> fetchFinishedDelegate;

- (instancetype)initWithSavedPageList:(MWKSavedPageList*)savedPageList;

- (void)getProgress:(WMFProgressHandler)progressBlock;

/**
 *  Start observing the saved page list and cache any articles and image data when itmes are added or removed.
 */
- (void)start;

/**
 *  Downloads any uncached articles and related images
 *  Will not redownload anything already cached
 */
- (void)downloadAllUncachedData;


/**
 *  Stop any in progress downloads of article and image data 
 */
- (void)cancelAllDownloads;


@end

NS_ASSUME_NONNULL_END
