#import "ElementRectDebugView.h"

@implementation ElementRectDebugView

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor blueColor].CGColor);
    CGContextFillRect(context, self.debugRect);
    CGContextStrokePath(context);
}

@end
