//
//  WMFFeedItemExtractFetcher.h
//  Wikipedia
//
//  Created by Brian Gerstle on 11/9/15.
//  Copyright © 2015 Wikimedia Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AnyPromise;

NS_ASSUME_NONNULL_BEGIN

/**
 *  Fetches a preview of the featured article for a given day from en.wikipedia.org.
 *
 *  This uses the TFA_title template which is (at time of writing and to the best of my knowledge) specific to EN wiki.
 */
@interface WMFEnglishFeaturedTitleFetcher : NSObject

/**
 *  Fetch a preview for a day's featured article.
 *
 *  @param date The date to fetch the featured article for, or @c nil to fetch today's featured article.
 *
 *  @return A promise with resolves to an @c MWKSearchResult.
 */
- (AnyPromise*)fetchFeaturedArticlePreviewForDate:(nullable NSDate*)date;

@end

NS_ASSUME_NONNULL_END
