//
//  NSDate+NSDate_Humane.h
//  Waker
//
//  Created by Anders Hovmöller on 2013-11-01.
//
//

#import <Foundation/Foundation.h>

@interface NSDate (NSDate_Humane)

- (NSUInteger)year;
- (NSUInteger)month;
- (NSUInteger)day;
- (NSUInteger)hour;
- (NSUInteger)minute;
- (NSUInteger)second;
- (NSUInteger)weekday;

- (NSString*)asCET;

+ (NSDate*)dateWithYear:(NSUInteger)year month:(NSUInteger)month day:(NSUInteger)day;
+ (NSDate*)dateWithYear:(NSUInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second;
+ (NSDateComponents*)dateComponentsWithDays:(NSUInteger)days hours:(NSUInteger)hours minutes:(NSUInteger)minutes seconds:(NSUInteger)seconds;
- (NSDate*)dateWithOffsetDays:(NSUInteger)days hours:(NSUInteger)hours minutes:(NSUInteger)minutes seconds:(NSUInteger)seconds;

- (BOOL)laterThan:(NSDate*)other;
- (BOOL)earlierThan:(NSDate*)other;

- (NSString*)relativeDescription;

@end