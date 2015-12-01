//  Created by Monte Hurd on 1/15/14.
//  Copyright (c) 2013 Wikimedia Foundation. Provided under MIT-style license; please copy and modify!

#import "UIViewController+Alert.h"
#import "UIView+RemoveConstraints.h"
#import "UIView+WMFSearchSubviews.h"
#import "Defines.h"

@implementation UIViewController (Alert)

- (void)showAlert:(id)alertText type:(AlertType)type duration:(CGFloat)duration {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self fadeAlert];

        if ([self shouldHideAlertForViewController:self]) {
            return;
        }

        AlertLabel* newAlertLabel =
            [[AlertLabel alloc] initWithText:alertText
                                    duration:duration
                                     padding:ALERT_PADDING
                                        type:type];

        newAlertLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:newAlertLabel];

        [self constrainAlertView:newAlertLabel type:type];
    }];
}

- (void)fadeAlert {
    // Fade existing alert labels if any.
    NSArray* alertLabels = [self.view wmf_subviewsOfClass:[AlertLabel class]];
    [alertLabels makeObjectsPerformSelector:@selector(fade)];
}

- (void)hideAlert {
    if (!self.isViewLoaded) {
        return;
    }
    // Hide existing alert labels if any.
    NSArray* alertLabels = [self.view wmf_subviewsOfClass:[AlertLabel class]];
    [alertLabels makeObjectsPerformSelector:@selector(hide)];
}

- (BOOL)shouldHideAlertForViewController:(UIViewController*)vc {
    BOOL hideAlerts = NO;
    if ([vc respondsToSelector:NSSelectorFromString(@"prefersAlertsHidden")]) {
        SEL selector = NSSelectorFromString(@"prefersAlertsHidden");
        if ([vc respondsToSelector:selector]) {
            NSInvocation* invocation =
                [NSInvocation invocationWithMethodSignature:[[vc class] instanceMethodSignatureForSelector:selector]];
            [invocation setSelector:selector];
            [invocation setTarget:vc];
            [invocation invoke];
            BOOL prefersAlertsHidden;
            [invocation getReturnValue:&prefersAlertsHidden];
            hideAlerts = (BOOL)prefersAlertsHidden;
        }
    } else {
        hideAlerts = NO;
    }
    return hideAlerts;
}

/*
   -(BOOL)isTopNavHiddenForViewController:(UIViewController *)vc
   {
    BOOL topNavHidden = NO;
    if ([vc respondsToSelector:NSSelectorFromString(@"prefersTopNavigationHidden")]) {
        SEL selector = NSSelectorFromString(@"prefersTopNavigationHidden");
        if ([vc respondsToSelector:selector]) {
            NSInvocation *invocation =
            [NSInvocation invocationWithMethodSignature: [[vc class] instanceMethodSignatureForSelector:selector]];
            [invocation setSelector:selector];
            [invocation setTarget:vc];
            [invocation invoke];
            BOOL prefersTopNavHidden;
            [invocation getReturnValue:&prefersTopNavHidden];
            topNavHidden = (BOOL)prefersTopNavHidden;
        }
    }else{
        topNavHidden = NO;
    }

    return topNavHidden;
   }
 */

- (void)constrainAlertView:(UIView*)view type:(AlertType)type;
{
    [view removeConstraintsOfViewFromView:self.view];

    CGFloat margin = 0;

    NSDictionary* views = @{
        @"view": view,
        @"topLayoutGuide": self.topLayoutGuide,
        @"bottomLayoutGuide": self.bottomLayoutGuide
    };

    NSDictionary* metrics = @{
        @"space": @(margin)
    };

    NSString* verticalFormatString = @"";
    switch (type) {
        case ALERT_TYPE_BOTTOM:
            verticalFormatString = @"V:[view]-(space)-[bottomLayoutGuide]";
            break;
        case ALERT_TYPE_FULLSCREEN:
            verticalFormatString = @"V:[topLayoutGuide]-(space)-[view]-(space)-[bottomLayoutGuide]";
            break;
        default: // ALERT_TYPE_TOP
            verticalFormatString = @"V:[topLayoutGuide]-(space)-[view]";
            break;
    }

    NSArray* viewConstraintArrays =
        @[
        [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(space)-[view]-(space)-|"
                                                options:0
                                                metrics:metrics
                                                  views:views],
        [NSLayoutConstraint constraintsWithVisualFormat:verticalFormatString
                                                options:0
                                                metrics:metrics
                                                  views:views]
    ];

    [self.view addConstraints:[viewConstraintArrays valueForKeyPath:@"@unionOfArrays.self"]];
}

@end
