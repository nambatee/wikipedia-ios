//
//  WMFTweaks.m
//  Wikipedia
//
//  Created by Corey Floyd on 8/17/16.
//  Copyright © 2016 Wikimedia Foundation. All rights reserved.
//

#import "WMFTweaks.h"
#import <Tweaks/FBTweakInline.h>

@implementation WMFTweaks

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static id sharedInstance;
    dispatch_once(&onceToken, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self registerTweaks];
    }
    return self;
}
- (void)registerTweaks{
    [self registerTweakWithCategory:@"Article" collection:@"Font Size" name:@"Step 1" defaultValue:@70];
    [self registerTweakWithCategory:@"Article" collection:@"Font Size" name:@"Step 2" defaultValue:@85];
    [self registerTweakWithCategory:@"Article" collection:@"Font Size" name:@"Step 3" defaultValue:@100];
    [self registerTweakWithCategory:@"Article" collection:@"Font Size" name:@"Step 4" defaultValue:@115];
    [self registerTweakWithCategory:@"Article" collection:@"Font Size" name:@"Step 5" defaultValue:@130];
    [self registerTweakWithCategory:@"Article" collection:@"Font Size" name:@"Step 6" defaultValue:@145];
    [self registerTweakWithCategory:@"Article" collection:@"Font Size" name:@"Step 4" defaultValue:@160];
}

- (FBTweakCategory*)categoryWithName:(NSString*)name{
    NSParameterAssert(name);
    FBTweakCategory* category = [[FBTweakStore sharedInstance] tweakCategoryWithName:name];
    if(category == nil){
        category = [[FBTweakCategory alloc] initWithName:name];
        [[FBTweakStore sharedInstance] addTweakCategory:category];
    }
    return category;
}


- (FBTweakCollection*)collectionWithName:(NSString*)name inCategory:(FBTweakCategory*)category{
    NSParameterAssert(name);
    NSParameterAssert(category);
    FBTweakCollection* collection = [category tweakCollectionWithName:name];
    if(collection == nil){
        collection = [[FBTweakCollection alloc] initWithName:name];
        [category addTweakCollection:collection];
    }
    return collection;
}

- (FBTweak*)tweakWithName:(NSString*)name inCategory:(FBTweakCategory*)category inCollection:(FBTweakCollection*)collection{
    NSParameterAssert(name);
    NSParameterAssert(category);
    NSParameterAssert(collection);

    NSString* identifier = [NSString stringWithFormat:@"%@.%@.%@", category.name, collection.name, name];
    FBTweak* tweak = [collection tweakWithIdentifier:identifier];
    if(tweak == nil){
        tweak = [[FBTweak alloc] initWithIdentifier:identifier];
        tweak.name = name;
        [collection addTweak:tweak];
    }
    return tweak;
}


- (FBTweak*)registerTweakWithCategory:(NSString*)category collection:(NSString*)collection name:(NSString*)name defaultValue:(id<NSCoding>)defaultValue{
    NSParameterAssert(name);
    NSParameterAssert(category);
    NSParameterAssert(collection);
    NSParameterAssert(defaultValue);

    FBTweakCategory* tweakCategory = [self categoryWithName:category];
    FBTweakCollection* tweakCollection = [self collectionWithName:collection inCategory:tweakCategory];
    FBTweak* tweak = [self tweakWithName:name inCategory:tweakCategory inCollection:tweakCollection];
    tweak.defaultValue = defaultValue;
    return tweak;
}

- (FBTweak*)registerTweakWithCategory:(NSString*)category collection:(NSString*)collection name:(NSString*)name defaultValue:(id<NSCoding>)defaultValue minimumValue:(id<NSCoding>)minimumValue maximumValue:(id<NSCoding>)maximumValue{
    FBTweak* tweak = [self registerTweakWithCategory:category collection:collection name:name defaultValue:defaultValue];
    tweak.minimumValue = minimumValue;
    tweak.maximumValue = maximumValue;
    
    return tweak;
}

- (id)tweakValueWithCategory:(NSString*)category collection:(NSString*)collection name:(NSString*)name{
    FBTweakCategory* tweakCategory = [self categoryWithName:category];
    FBTweakCollection* tweakCollection = [self collectionWithName:collection inCategory:tweakCategory];
    FBTweak* tweak = [self tweakWithName:name inCategory:tweakCategory inCollection:tweakCollection];
    return tweak.currentValue;
}



- (id)fontSize1{
    return [self tweakValueWithCategory:@"Article" collection:@"Font Size" name:@"Step 1"];
}
- (id)fontSize2{
    return [self tweakValueWithCategory:@"Article" collection:@"Font Size" name:@"Step 2"];
}
- (id)fontSize3{
    return [self tweakValueWithCategory:@"Article" collection:@"Font Size" name:@"Step 3"];
}
- (id)fontSize4{
    return [self tweakValueWithCategory:@"Article" collection:@"Font Size" name:@"Step 4"];
}
- (id)fontSize5{
    return [self tweakValueWithCategory:@"Article" collection:@"Font Size" name:@"Step 5"];
}
- (id)fontSize6{
    return [self tweakValueWithCategory:@"Article" collection:@"Font Size" name:@"Step 6"];
}
- (id)fontSize7{
    return [self tweakValueWithCategory:@"Article" collection:@"Font Size" name:@"Step 7"];
}







@end
