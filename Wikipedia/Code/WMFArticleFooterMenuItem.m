
#import "WMFArticleFooterMenuItem.h"

@interface WMFArticleFooterMenuItem ()

@property (nonatomic, copy, readwrite) NSString* title;

@property (nonatomic, copy, readwrite) NSString* imageName;

@property (nonatomic, assign, readwrite) WMFArticleFooterMenuItemType type;

@end

@implementation WMFArticleFooterMenuItem

- (instancetype)initWithType:(WMFArticleFooterMenuItemType)type
                       title:(NSString*)title
                   imageName:(NSString*)imageName {
    self = [super init];
    if (self) {
        self.type      = type;
        self.title     = title;
        self.imageName = imageName;
    }
    return self;
}

@end
