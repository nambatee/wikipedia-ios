#import "WMFDataSource.h"


@interface WMFDataSource ()

@property (nonatomic, strong) NSMutableDictionary* observers;

@end

@implementation WMFDataSource

- (id)init {
    self = [super init];
    if (self) {
        self.observers = [NSMutableDictionary dictionaryWithCapacity:2];
    }
    return self;
}

- (void)addObserver:(id <WMFDataSourceObserver>)observer {
    [self.observers setObject:[NSValue valueWithNonretainedObject:observer] forKey:@([observer hash])];
}

- (void)removeObserver:(id <WMFDataSourceObserver>)observer {
    [self.observers removeObjectForKey:@([observer hash])];
}

- (void)enumerateObserversUsingBlock:(WMFDataSourceObserverHandler)handler {
    NSArray* allValues = [self.observers.allValues copy];
    for (NSValue* value in allValues) {
        id <WMFDataSourceObserver> observer = [value nonretainedObjectValue];
        handler(observer);
    }
}

- (void)didChangeContent {
    [self enumerateObserversUsingBlock:^(id<WMFDataSourceObserver>  _Nonnull observer) {
        [observer dataSourceDidChangeContent:self];
    }];
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section {
    return 0;
}

- (nullable id)itemAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (NSInteger)numberOfSections {
    return 0;
}

- (NSInteger)numberOfItems {
    NSInteger numberOfSections = self.numberOfSections;
    NSInteger total = 0;
    for (NSInteger section = 0; section < numberOfSections; section++) {
        total += [self numberOfItemsInSection:section];
    }
    return total;
}


@end
