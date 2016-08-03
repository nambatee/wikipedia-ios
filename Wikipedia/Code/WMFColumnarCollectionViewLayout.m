#import "WMFColumnarCollectionViewLayout.h"
#import "WMFCVLInfo.h"
#import "WMFCVLColumn.h"
#import "WMFCVLSection.h"
#import "WMFCVLAttributes.h"
#import "WMFCVLInvalidationContext.h"
#import "WMFCVLMetrics.h"

@interface WMFColumnarCollectionViewLayout ()

@property (nonatomic, readonly) id <WMFColumnarCollectionViewLayoutDelegate> delegate;
@property (nonatomic, strong) WMFCVLMetrics *metrics;
@property (nonatomic, strong) WMFCVLInfo *info;

@end

@implementation WMFColumnarCollectionViewLayout

- (nonnull instancetype)initWithMetrics:(nonnull WMFCVLMetrics *)metrics {
    self = [super init];
    if (self) {
        self.metrics = metrics;
    }
    return self;
}

- (instancetype)init {
    return [self initWithMetrics:[WMFCVLMetrics defaultMetrics]];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        if (!self.metrics) {
            self.metrics = [WMFCVLMetrics defaultMetrics];
        }
    }
    return self;
}

#pragma mark - Classes

+ (Class)invalidationContextClass {
    return [WMFCVLInvalidationContext class];
}

+ (Class)layoutAttributesClass {
    return [WMFCVLAttributes class];
}

#pragma mark - Properties

- (id <WMFColumnarCollectionViewLayoutDelegate>)delegate {
    assert(self.collectionView.delegate == nil || [self.collectionView.delegate conformsToProtocol:@protocol(WMFColumnarCollectionViewLayoutDelegate)]);
    return (id <WMFColumnarCollectionViewLayoutDelegate>)self.collectionView.delegate;
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section {
    return [self.collectionView.dataSource collectionView:self.collectionView numberOfItemsInSection:section];
}

- (CGSize)collectionViewContentSize {
    return self.info.contentSize;
}

#pragma mark - Layout

- (nullable NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    
    NSMutableArray *attributesArray = [NSMutableArray array];
    
    
    [self.info enumerateSectionsWithBlock:^(WMFCVLSection * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
        if (CGRectIntersectsRect(section.frame, rect)) {
            [section enumerateLayoutAttributesWithBlock:^(WMFCVLAttributes *attributes, BOOL *stop) {
                if (CGRectIntersectsRect(attributes.frame, rect)) {
                    [attributesArray addObject:attributes];
                }
            }];
        }
    }];
    
#if DEBUG
    NSMutableIndexSet *headerSections = [NSMutableIndexSet indexSet];
    for (UICollectionViewLayoutAttributes *attributes in attributesArray) {
        NSLog(@"\n%i.%i:\t%@", (int)attributes.indexPath.section, (int)attributes.indexPath.row, attributes.representedElementKind);
        if ([attributes.representedElementKind isEqualToString:UICollectionElementKindSectionHeader]) {
            if ([headerSections containsIndex:attributes.indexPath.section]) {
                NSLog(@"bad");
            }
            [headerSections addIndex:attributes.indexPath.section];
        }
    }
#endif
    
    return attributesArray;
}

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self.info layoutAttributesForItemAtIndexPath:indexPath];
}

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath {
    return [self.info layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:indexPath];
}

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString*)elementKind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (void)resetLayout {
    self.info = [[WMFCVLInfo alloc] initWithMetrics:self.metrics];
    [self.info updateWithInvalidationContext:nil delegate:self.delegate collectionView:self.collectionView];
}

- (void)prepareLayout {
    if (self.info == nil) {
        [self resetLayout];
    }
    [super prepareLayout];
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset {
    return proposedContentOffset;
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity {
    return proposedContentOffset;
}

#pragma mark - Invalidation

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return newBounds.size.width != self.info.boundsSize.width;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds {
    WMFCVLInvalidationContext *context = (WMFCVLInvalidationContext *)[super invalidationContextForBoundsChange:newBounds];
    context.boundsDidChange = YES;
    context.newBounds = newBounds;
    [self.info updateWithInvalidationContext:context delegate:self.delegate collectionView:self.collectionView];
    return context;
}

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes {
    return !CGRectEqualToRect(preferredAttributes.frame, originalAttributes.frame);
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes {
    WMFCVLInvalidationContext *context = (WMFCVLInvalidationContext *)[super invalidationContextForPreferredLayoutAttributes:preferredAttributes withOriginalAttributes:originalAttributes];
    if (context == nil) {
        context = [WMFCVLInvalidationContext new];
    }
    context.preferredLayoutAttributes = preferredAttributes;
    context.originalLayoutAttributes = originalAttributes;
    [self.info updateWithInvalidationContext:context delegate:self.delegate collectionView:self.collectionView];
    
#if DEBUG
    for (NSIndexPath *indexPath in context.invalidatedItemIndexPaths) {
        assert(indexPath.section > originalAttributes.indexPath.section || (indexPath.section == originalAttributes.indexPath.section && indexPath.item >= originalAttributes.indexPath.item));
    }
    
    for (NSIndexPath *indexPath in context.invalidatedSupplementaryIndexPaths[UICollectionElementKindSectionHeader]) {
        assert(indexPath.section >= originalAttributes.indexPath.section);
    }
    
    for (NSIndexPath *indexPath in context.invalidatedSupplementaryIndexPaths[UICollectionElementKindSectionFooter]) {
        assert(indexPath.section >= originalAttributes.indexPath.section);
    }
#endif
    return context;
}

- (void)invalidateLayoutWithContext:(WMFCVLInvalidationContext *)context {
    assert([context isKindOfClass:[WMFCVLInvalidationContext class]]);
    if (context.invalidateEverything) {
        [self resetLayout];
    } else if (context.invalidateDataSourceCounts) {
        [self.info updateWithInvalidationContext:context delegate:self.delegate collectionView:self.collectionView];
    }
    [super invalidateLayoutWithContext:context];
}

#pragma mark - UIUpdateSupportHooks

- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems {
    [super prepareForCollectionViewUpdates:updateItems];
    for (UICollectionViewUpdateItem *updateItem in updateItems) {
        NSInteger section = updateItem.indexPathBeforeUpdate.section;
        NSInteger item = updateItem.indexPathBeforeUpdate.item;
        if (item > [self numberOfItemsInSection:section]) {
            switch (updateItem.updateAction) {
                case UICollectionUpdateActionInsert:
                    NSLog(@"insert");
                    break;
                case UICollectionUpdateActionDelete:
                    NSLog(@"delete");
                    break;
                case UICollectionUpdateActionReload:
                    NSLog(@"reload");
                    break;
                case UICollectionUpdateActionMove:
                    NSLog(@"move");
                    break;
                case UICollectionUpdateActionNone:
                default:
                    break;
            }
        } else {
            switch (updateItem.updateAction) {
                case UICollectionUpdateActionInsert:
                case UICollectionUpdateActionDelete:
                case UICollectionUpdateActionReload:
                case UICollectionUpdateActionMove:
                case UICollectionUpdateActionNone:
                default:
                    break;
            }
        }
    }
}

- (void)finalizeCollectionViewUpdates {
    [super finalizeCollectionViewUpdates];
}

- (void)prepareForAnimatedBoundsChange:(CGRect)oldBounds {
    [super prepareForAnimatedBoundsChange:oldBounds];
}

- (void)finalizeAnimatedBoundsChange {
    [super finalizeAnimatedBoundsChange];
}

- (void)prepareForTransitionToLayout:(UICollectionViewLayout *)newLayout {
    
}

- (nullable UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath {
    WMFCVLAttributes *attributes = [[self layoutAttributesForItemAtIndexPath:itemIndexPath] copy];
    attributes.alpha = 0;
    return attributes;
}

- (nullable UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)itemIndexPath {
    WMFCVLAttributes *attributes = [[self layoutAttributesForItemAtIndexPath:itemIndexPath] copy];
    attributes.alpha = 0;
    return attributes;
}

- (nullable UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingSupplementaryElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)elementIndexPath {
    WMFCVLAttributes *attributes = [[self layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:elementIndexPath] copy];
    attributes.alpha = 0;
    return attributes;
}

- (nullable UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingSupplementaryElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)elementIndexPath {
    WMFCVLAttributes *attributes = [[self layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:elementIndexPath] copy];
    attributes.alpha = 0;
    return attributes;
}

- (nullable UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingDecorationElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)decorationIndexPath {
    WMFCVLAttributes *attributes = [[self layoutAttributesForDecorationViewOfKind:elementKind atIndexPath:decorationIndexPath] copy];
    attributes.alpha = 0;
    return attributes;
}

- (nullable UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingDecorationElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)decorationIndexPath {
    WMFCVLAttributes *attributes = [[self layoutAttributesForDecorationViewOfKind:elementKind atIndexPath:decorationIndexPath] copy];
    attributes.alpha = 0;
    return attributes;
}


- (NSArray<NSIndexPath *> *)indexPathsToDeleteForSupplementaryViewOfKind:(NSString *)elementKind {
    NSArray<NSIndexPath *> *indexPathsToDelete = [super indexPathsToDeleteForSupplementaryViewOfKind:elementKind];
    return @[];
}

- (NSArray<NSIndexPath *> *)indexPathsToDeleteForDecorationViewOfKind:(NSString *)elementKind {
    NSArray<NSIndexPath *> *indexPathsToDelete = [super indexPathsToDeleteForDecorationViewOfKind:elementKind];
    return indexPathsToDelete;
}

- (NSArray<NSIndexPath *> *)indexPathsToInsertForSupplementaryViewOfKind:(NSString *)elementKind {
    NSArray<NSIndexPath *> *indexPathsToInsert = [super indexPathsToInsertForSupplementaryViewOfKind:elementKind];
    return @[];
}

- (NSArray<NSIndexPath *> *)indexPathsToInsertForDecorationViewOfKind:(NSString *)elementKind {
    NSArray<NSIndexPath *> *indexPathsToInsert = [super indexPathsToInsertForDecorationViewOfKind:elementKind];
    return indexPathsToInsert;
}

@end

