#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "waker.h"
#import "NSDate+NSDate_Humane.h"
#import "Waker_AppDelegate.h"
#import "EventKit/EventKit.h"

EKEventStore *_store = nil;

EKEventStore* get_store() {
    if (_store == nil) {
        _store = [[EKEventStore alloc] init];
        [_store requestFullAccessToEventsWithCompletion:^(BOOL granted, NSError * _Nullable error) {
            printf("asd", granted, error);
        }];
    }
    return _store;
}

@implementation AlarmTimeAndRule

+ (instancetype)newWithNextAlarm:(NSDate*)next_alarm rule:(NSString*)rule {
    AlarmTimeAndRule* s = [[AlarmTimeAndRule alloc] init];
    s->next_alarm = next_alarm;
    s->rule = rule;
    return s;
}

@end


static NSDictionary* _weekday_to_string = nil;
NSDictionary* get_weekday_to_string(void) {
    if (_weekday_to_string == nil) {
        _weekday_to_string = @{
            @0: @"monday",
            @1: @"tuesday",
            @2: @"wednesday",
            @3: @"thursday",
            @4: @"friday",
            @5: @"saturday",
            @6: @"sunday"};
    }
    return _weekday_to_string;
}

static NSDictionary* _month_to_string = nil;
NSDictionary* get_month_to_string(void) {
    if (_month_to_string == nil) {
        _month_to_string = @{
            @1: @"January",
            @2: @"February",
            @3: @"March",
            @4: @"April",
            @5: @"May",
            @6: @"June",
            @7: @"July",
            @8: @"August",
            @9: @"September",
            @10: @"October",
            @11: @"November",
            @12: @"December"};
    }
    return _month_to_string;
}

NSArray* events_of_day(NSUInteger year, NSUInteger month, NSUInteger day) {
    NSDate* date = [NSDate dateWithYear:year month:month day:day];
    NSDate* startDate = [date dateWithOffsetDays:0 hours:0 minutes:0 seconds:1];
    NSDate* endDate = [date dateWithOffsetDays:1 hours:0 minutes:0 seconds:-1];
    EKEventStore *store = get_store();
    NSArray* calendars = [store calendarsForEntityType:EKEntityTypeEvent];
    NSPredicate* allEventsPredicate = [store predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendars];
    NSArray* events = [store eventsMatchingPredicate:allEventsPredicate];
    return events;
}

BOOL matches_rule(NSArray* events, NSDate* date, NSManagedObject* rule) {
    if ([events count] == 0) {
        return NO;
    }
    if ([rule predicate] == nil) {
        return YES;
    }
    NSNumber* day_of_week = get_weekday_to_string()[[NSNumber numberWithInt:[date weekday]]];
    NSMutableDictionary* foo = [@{} mutableCopy];
    [foo setValue:day_of_week forKey:@"day"];
    NSString* predicate = [rule predicate];
    if ([[NSPredicate predicateWithFormat:predicate] evaluateWithObject:foo]) {
        return YES;
    }
    for (EKEvent* event in events) {
        if (event.title)
            [foo setValue:event.title forKey:@"title"];
        if (event.location)
            [foo setValue:event.location forKey:@"location"];
        if (event.notes)
            [foo setValue:event.notes forKey:@"notes"];
        if (event.URL)
            [foo setValue:event.URL forKey:@"url"];
        
        if ([[NSPredicate predicateWithFormat:predicate] evaluateWithObject:foo]) {
            return YES;
        }
    }
    return [[NSPredicate predicateWithFormat:[rule predicate]] evaluateWithObject:@{@"day": day_of_week}];
//    }
//    @catch (id) {
//        NSLog(@"Warning: matches_rule failed, ignoring...");
//        return NO;
//    }
}

NSManagedObject* get_rule(id<Settings> settings, NSUInteger year, NSUInteger month, NSUInteger day) {
    NSArray* events = events_of_day(year, month, day);
    NSDate* date = [NSDate dateWithYear:year month:month day:day];
    for (NSManagedObject* rule in [settings rules]) {
        if (matches_rule(events, date, rule)) {
            return rule;
        }
    }
    return nil;
}

NSString* get_classification(id<Settings> settings, NSUInteger year, NSUInteger month, NSUInteger day) {
    NSManagedObject* rule = get_rule(settings, year, month, day);
    if (rule == nil) {
        return nil;
    }
    return [rule name];
}

AlarmTimeAndRule* get_alarm_time_and_rule(id<Settings> settings, NSUInteger year, NSUInteger month, NSUInteger day) {
    NSDate* date = [NSDate dateWithYear:year month:month day:day];
    NSArray* events = events_of_day(year, month, day);
    for (NSManagedObject* rule in [settings rules]) {
        if (matches_rule(events, date, rule)) {
            if ([rule time] == nil) {
                return [AlarmTimeAndRule newWithNextAlarm:nil rule:[rule name]];
            }
            else {
                NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
                [formatter setDateFormat:@"HH:mm"];
                NSDate* next_alarm = [formatter dateFromString:[rule time]];
                next_alarm = [NSDate dateWithYear:year month:month day:day hour:next_alarm.hour minute:next_alarm.minute second:next_alarm.second];
                return [AlarmTimeAndRule newWithNextAlarm:next_alarm rule:rule.name];
            }
        }
    }
    return nil;
}

AlarmTimeAndRule* get_next_alarm_time_and_rule(id<Settings> settings, NSDate* in_reference_date) {
    NSDate* reference_date = nil;
    if (in_reference_date == nil) {
        in_reference_date = [NSDate date];
        reference_date = in_reference_date;
    }
    else {
        reference_date = [reference_date dateWithOffsetDays:1 hours:0 minutes:0 seconds:0]; // skip the rest of the day
    }
    AlarmTimeAndRule* result = get_alarm_time_and_rule(settings, reference_date.year, reference_date.month, reference_date.day);
    if (result == nil) {
        return nil;
    }
    // TODO: prevent infinite loops here
    NSDate* lookahead_limit = [reference_date dateWithOffsetDays:3*30 hours:0 minutes:0 seconds:0];
    while ([reference_date earlierThan:lookahead_limit] && (result == nil || result->next_alarm == nil || [result->next_alarm earlierThan:in_reference_date])) {
        reference_date = [reference_date dateWithOffsetDays:1 hours:0 minutes:0 seconds:0];
        result = get_alarm_time_and_rule(settings, reference_date.year, reference_date.month, reference_date.day);
    }
    return result;
}

