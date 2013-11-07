#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "NSDate+NSDate_Humane.h"

@interface DateTransformer : NSValueTransformer {
}
@end

@interface DidNotUnderstandException : NSException {
}
@end

@interface PredicateTransformer : NSValueTransformer {
}
+ (BOOL)allowsReverseTransformation;
+ (Class)transformedValueClass;
@end

@interface NothingTransformer : NSValueTransformer {
}
@end

@interface DisableAlarmTransformer : NSValueTransformer {
}
+ (BOOL)allowsReverseTransformation;
+ (Class)transformedValueClass;
@end

@interface NumberTransformer : NSValueTransformer {
}
@end

@interface ColorTransformer : NSValueTransformer {
}
+ (BOOL)allowsReverseTransformation;
+ (Class)transformedValueClass;
@end

@interface EnableAlarmTransformer : NSValueTransformer {
}
+ (BOOL)allowsReverseTransformation;
+ (Class)transformedValueClass;
@end

NSColor* IntToNSColor(int value);
NSInteger NSColorToInt(NSColor* color);
NSDate* NSDateFromString(NSString* str);
