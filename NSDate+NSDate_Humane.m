//
//  NSDate+NSDate_Humane.m
//  Waker
//
//  Created by Anders Hovmöller on 2013-11-01.
//
//

#import "NSDate+NSDate_Humane.h"

@implementation NSDate (NSDate_Humane)

- (NSUInteger)year {
    return [[[NSCalendar currentCalendar] components:NSYearCalendarUnit fromDate:self] year];
}

- (NSUInteger)month {
    return [[[NSCalendar currentCalendar] components:NSMonthCalendarUnit fromDate:self] month];
}

- (NSUInteger)day {
    return [[[NSCalendar currentCalendar] components:NSDayCalendarUnit fromDate:self] day];
}

- (NSUInteger)hour {
    return [[[NSCalendar currentCalendar] components:NSHourCalendarUnit fromDate:self] hour];
}

- (NSUInteger)minute {
    return [[[NSCalendar currentCalendar] components:NSMinuteCalendarUnit fromDate:self] minute];
}

- (NSUInteger)second {
    return [[[NSCalendar currentCalendar] components:NSSecondCalendarUnit fromDate:self] second];
}

- (NSUInteger)ordinal {
    return [[[NSCalendar currentCalendar] components:NSWeekdayOrdinalCalendarUnit fromDate:self] weekdayOrdinal];
}

- (NSUInteger)weekday {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    int weekday = [[calendar components:NSWeekdayCalendarUnit fromDate:self] weekday]-2; // -2 because cocoa APIs are stupid and counts sunday as 1, while monday as 0 is the only thing that makes sense
    if (weekday == -1) {
        weekday = 6;
    }
    return weekday;
}

- (NSString*)asCET {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm";
    
    NSTimeZone *CET = [NSTimeZone timeZoneWithAbbreviation:@"CET"];
    [dateFormatter setTimeZone:CET];
    NSString *timeStamp = [dateFormatter stringFromDate:[NSDate date]];
    return timeStamp;
}

+ (NSDateComponents*)dateComponentsWithYear:(NSUInteger)year month:(NSUInteger)month day:(NSUInteger)day hours:(NSUInteger)hours minutes:(NSUInteger)minutes seconds:(NSUInteger)seconds {
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setYear:year];
    [comps setMonth:month];
    [comps setDay:day];
    [comps setHour:hours];
    [comps setMinute:minutes];
    [comps setSecond:seconds];
    return comps;
}

+ (NSDateComponents*)dateComponentsWithDays:(NSUInteger)days hours:(NSUInteger)hours minutes:(NSUInteger)minutes seconds:(NSUInteger)seconds {
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setDay:days];
    [comps setHour:hours];
    [comps setMinute:minutes];
    [comps setSecond:seconds];
    [comps setTimeZone:[NSTimeZone localTimeZone]];
    return comps;
}


+ (NSDate*)dateWithYear:(NSUInteger)year month:(NSUInteger)month day:(NSUInteger)day {
    return [NSDate dateWithYear:year month:month day:day hour:0 minute:0 second:0];
}

+ (NSDate*)dateWithYear:(NSUInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second {
    return [[NSCalendar currentCalendar] dateFromComponents:[NSDate dateComponentsWithYear:year month:month day:day hours:hour minutes:minute seconds:second]];
}


- (NSDate*)dateWithOffsetDays:(NSUInteger)days hours:(NSUInteger)hours minutes:(NSUInteger)minutes seconds:(NSUInteger)seconds {
    return [[NSCalendar currentCalendar] dateByAddingComponents:[NSDate dateComponentsWithDays:days hours:hours minutes:minutes seconds:(NSUInteger)seconds] toDate:self options:0];
}

- (BOOL)laterThan:(NSDate*)other {
    return [self compare:other] == NSOrderedDescending;
}

- (BOOL)earlierThan:(NSDate*)other {
    return [self compare:other] == NSOrderedAscending;
}

- (NSString *)relativeDateString
{
    const int SECOND = 1;
    const int MINUTE = 60 * SECOND;
    const int HOUR = 60 * MINUTE;
    const int DAY = 24 * HOUR;
    const int MONTH = 30 * DAY;
    
    NSDate *now = [NSDate date];
    NSTimeInterval delta = [self timeIntervalSinceDate:now] * -1.0;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger units = (NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit);
    NSDateComponents *components = [calendar components:units fromDate:self toDate:now options:0];
    
    NSString *relativeString;
    
    if (delta < 0) {
        relativeString = @"!n the future!";
        
    } else if (delta < 1 * MINUTE) {
        relativeString = (components.second == 1) ? @"One second ago" : [NSString stringWithFormat:@"%ld seconds ago",(long)components.second];
        
    } else if (delta < 2 * MINUTE) {
        relativeString =  @"a minute ago";
        
    } else if (delta < 45 * MINUTE) {
        relativeString = [NSString stringWithFormat:@"%ld minutes ago",(long)components.minute];
        
    } else if (delta < 90 * MINUTE) {
        relativeString = @"an hour ago";
        
    } else if (delta < 24 * HOUR) {
        relativeString = [NSString stringWithFormat:@"%ld hours ago",(long)components.hour];
        
    } else if (delta < 48 * HOUR) {
        relativeString = @"yesterday";
        
    } else if (delta < 30 * DAY) {
        relativeString = [NSString stringWithFormat:@"%ld days ago",(long)components.day];
        
    } else if (delta < 12 * MONTH) {
        relativeString = (components.month <= 1) ? @"one month ago" : [NSString stringWithFormat:@"%ld months ago",(long)components.month];
        
    } else {
        relativeString = (components.year <= 1) ? @"one year ago" : [NSString stringWithFormat:@"%ld years ago",(long)components.year];
        
    }
    
    return relativeString;
}

- (NSString*)relativeDescription {
    NSDate* reference_date = [NSDate date];
    NSTimeInterval diff = [self timeIntervalSinceDate:reference_date];

    NSString* time_formatting = @"";

//    if (show_seconds) {
//        time_formatting = @"%H:%M:%S";
//    }
//    else
    if (abs([self ordinal] - [reference_date ordinal]) <= 1) {
        time_formatting = @"HH:mm";
    }
    
    if ([self ordinal] == [reference_date ordinal]) {
        NSString* s = @"";

        if ([self laterDate:reference_date]) { // in future
            s = [NSString stringWithFormat:@"in %@", s];
        }
        
        diff = abs(diff);
        if (diff >= 60*60) {
            int hours = diff/60/60;
            s = [NSString stringWithFormat:@"%@%d h ", s, hours];
        }
        if (diff >= 60) {
            int minutes = (int)diff/60 % 60;
            s = [NSString stringWithFormat:@"%@%d min ", s, minutes];
        }
        if (diff < 60) {
            s = [NSString stringWithFormat:@"%@%d s ", s, (int)diff];
        }
        
        if (self < reference_date) { // in the past
            s = [NSString stringWithFormat:@"%@ago", s];
        }
        
        return s;
    }
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:time_formatting];
    
    if ([self ordinal] - [reference_date ordinal] == -1) {
        return [NSString stringWithFormat:@"yesterday at %@", [formatter stringFromDate:self]];
    }
    else if ([self ordinal] - [reference_date ordinal] == 1) {
        return [NSString stringWithFormat:@"tomorrow at %@", [formatter stringFromDate:self]];
    }
    else if (self.year != reference_date.year) {
        [formatter setDateFormat:[@"dd MM yyyy %@" stringByAppendingString:time_formatting]];
        return [formatter stringFromDate:self];
    }
    else {
        [formatter setDateFormat:[@"dd MM %@" stringByAppendingString:time_formatting]];
        return [formatter stringFromDate:self];
    }
}

@end
