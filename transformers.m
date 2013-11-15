 #import "transformers.h"

NSDate* NSDateFromString(NSString* str) {
    if ([str hasPrefix:@"in "]) {
        str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSError *error = nil;
        NSRegularExpression* re = [NSRegularExpression regularExpressionWithPattern:@"in (\\d+)\\s*(.*)" options:NSRegularExpressionCaseInsensitive error:&error];
        NSTextCheckingResult* m = [re firstMatchInString:str options:0 range:NSMakeRange(0, str.length)];
        if (m) {
            NSRange numRange = [m rangeAtIndex:1];
            NSRange unitRange = [m rangeAtIndex:2];
            float num = [[str substringWithRange:numRange] floatValue];
            NSString* unit = [str substringWithRange:unitRange];
            NSDictionary* lookup = @{
                @"second": @1,
                @"seconds": @1,
                @"secs": @1,
                @"s": @1,
                @"minute": @60,
                @"min": @60,
                @"mins": @60,
                @"m": @60,
                @"hours": @(60*60),
                @"hour": @(60*60),
                @"h": @(60*60),
                @"days": @(60*60*24),
                @"day": @(60*60*24),
                @"d": @(60*60*24),
                };
            if (lookup[unit] != nil) {
                return [[NSDate date] dateWithOffsetDays:0 hours:0 minutes:0 seconds:num * [lookup[unit] intValue]];
            }
        }
//        [[DidNotUnderstandException alloc] raise];
    }
    NSDate* date = [NSDate dateWithNaturalLanguageString:str];
    // TODO: now convert it to GMT for the internal processing
    if (date == nil) {
        [[DidNotUnderstandException alloc] raise];
    }
    return date;
}

NSColor* IntToNSColor(int value) {
    float
        red = ((value & 0xFF0000) >> 16) / 255.0,
        green = ((value & 0xFF00) >> 8) / 255.0,
        blue = (value & 0xFF) / 255.0;
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1];
}

NSInteger NSColorToInt(NSColor* color) {
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    int foo = (int)(red * 255) << 16 | (int)(green * 255) << 8 | (int)(blue * 255);
    return foo;
}

@implementation DidNotUnderstandException

- (id)description {
    return @"I'm sorry, I didn't understand that";
}

@end


@implementation DateTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    // string in, string out
    if (value == nil) {
        return @"n/a";
    }
    return value;
}

- (id)reverseTransformedValue:(id)value {
    // string in, string out
    if ([@"n/a" isEqualToString:value]) {
        return nil;
    }
    return value;
}

@end


@implementation NumberTransformer

+ (Class)transformedValueClass {
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    return [value description];
}

- (id)reverseTransformedValue:(id)value {
    if (value == nil) {
        return 0;
    }
    return [NSNumber numberWithInt:[value intValue]];
}

@end


@implementation NothingTransformer

+ (id)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    return value;
}

- (id)reverseTransformedValue:(id)value {
    return value;
}

@end

@implementation ColorTransformer

+ (Class)transformedValueClass {
    return [NSColor class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    return IntToNSColor([value intValue]);
}

- (id)reverseTransformedValue:(id)value {
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [value getRed:&red green:&green blue:&blue alpha:&alpha];
    int foo = (int)(red * 255) << 16 | (int)(green * 255) << 8 | (int)(blue * 255);
    return [NSNumber numberWithInt:foo];
}

@end


@implementation PredicateTransformer : NSValueTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    if (value == nil) {
        value = @"title CONTAINS \"\"";
    }
    NSPredicate* predicate = [NSPredicate predicateWithFormat:value];
    if ([predicate class] != [NSCompoundPredicate class]) {
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate]];
    }
    return predicate;
}

- (id)reverseTransformedValue:(id)value {
    if (value == nil) {
        return nil;
    }
    return [value predicateFormat];
}

@end


@implementation DisableAlarmTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    //print 'disable1', value, type(value)
    // NSDate in, string out
    if (value == nil) {
        return @YES;
    }
    return @NO;
}

- (id)reverseTransformedValue:(id)value {
    //print 'disable2', value, type(value)
    if (value == nil) {
        return @"8:00";
    }
    return nil;
}

@end


@implementation EnableAlarmTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    // NSDate in, string out
    if ([value boolValue] == NO) {
        return @NO;
    }
    return @YES;
}

- (id)reverseTransformedValue:(id)value {
    if ([value boolValue] == YES) {
        return NSDateFromString(@"8:00");
    }
    return nil;
}

@end
