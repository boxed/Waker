#import <Foundation/Foundation.h>
#import <CalendarStore/CalendarStore.h>
#import <CoreData/CoreData.h>

@interface Rule {
    id _name;
    id _predicate;
    id _priority;
    id _time;
}
@end

@protocol Settings
- (NSArray*)rules;
@end


@interface AlarmTimeAndRule : NSObject  {
@public NSDate* next_alarm;
@public NSString* rule;
}
+ (instancetype)newWithNextAlarm:(NSDate*)next_alarm rule:(NSString*)rule;
@end


NSDictionary* get_weekday_to_string(void);
NSDictionary* get_month_to_string(void);
NSArray* events_of_day(NSUInteger year, NSUInteger month, NSUInteger date);
BOOL matches_rule(NSArray* events, NSDate* date, NSManagedObject* rule);
NSManagedObject* get_rule(id<Settings> settings, NSUInteger year, NSUInteger month, NSUInteger day);
NSString* get_classification(id<Settings> settings, NSUInteger year, NSUInteger month, NSUInteger day);
AlarmTimeAndRule* get_alarm_time_and_rule(id<Settings> settings, NSUInteger year, NSUInteger month, NSUInteger day);
AlarmTimeAndRule* get_next_alarm_time_and_rule(id<Settings> settings, NSDate* in_reference_date);
