#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "CalendarView.h"
#import "NSDate+NSDate_Humane.h"
#import "transformers.h"
#import "waker.h"
#import "Waker_AppDelegate.h"

static NSDictionary* _weekday_to_string = nil;
static NSDictionary* _month_to_string = nil;

static NSDictionary* weekday_to_string(void);
static NSDictionary* month_to_string(void);

static void fillRect(NSRect r, NSColor* color) {
    NSBezierPath* bp = [NSBezierPath bezierPathWithRect:r];
    [color set];
    [bp fill];
}

static NSString* date_to_key(int year, int month, int date) {
    return [NSString stringWithFormat:@"%d %d %d", year, month, date];
}


static NSArray* monthcalendar(int year, int month) {
    NSDateComponents* comps = [[NSDateComponents alloc] init];
    [comps setDay:1];
    [comps setMonth:month];
    [comps setYear:year];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate* monthDate = [calendar dateFromComponents:comps];
    
    NSRange r = [calendar rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:monthDate];
    int number_of_days_in_month = r.length;
    int weekday = [monthDate weekday];
    NSMutableArray* result = [@[] mutableCopy];
    NSMutableArray* row = nil;
    for (int day = 1; day != number_of_days_in_month+1; day++) {
        if (row == nil) {
            row = [@[] mutableCopy];
            [result addObject:row];
        }
        if (day == 1) {
            // Pad 0s from last month
            for (int x = 0; x != weekday; x++) {
                [row addObject:[NSNumber numberWithInt:0]];
            }
        }
        
        [comps setDay:day];
        NSDate* today = [calendar dateFromComponents:comps];
        [row addObject:[NSNumber numberWithInt:day]];
        if ([today weekday] == 6) {
            row = nil;
        }
    }
    
    return result;
}


NSDictionary* weekday_to_string(void) {
    if (_weekday_to_string == nil) {
        _weekday_to_string = @{
            @0: @"monday",
            @1: @"tuesday",
            @2: @"wednesday",
            @3: @"thursday",
            @4: @"friday",
            @5: @"saturday",
            @6: @"sunday",
        };
    }
    return _weekday_to_string;
}

NSDictionary* month_to_string(void) {
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
            @12: @"December",
        };
    }
    return _month_to_string;
}

@implementation CalendarView : NSView

- (void)awakeFromNib {
    NSDate* now = [NSDate new];
    
    self->_year = now.year;
    self->_month = now.month;
    [self->progress stopAnimation:self];
    [self updateTitle];
    self->loading = false;
    self->loadingThread = nil;
    self->cache = [@{} mutableCopy];
}

- (void)updateTitle {
    [self setNeedsDisplay:YES];
    NSDictionary* d = month_to_string();
    [self->title setStringValue:[NSString stringWithFormat:@"Preview of %@ %d", [d objectForKey:[NSNumber numberWithInt:self->_month]], self->_year]];
}

- (IBAction)nextMonth:(id __unused)sender {
    self->_month += 1;
    if (self->_month == 13) {
        self->_year += 1;
        self->_month = 1;
    }
    [self updateTitle];
}

- (IBAction)previousMonth:(id __unused)sender {
    self->_month -= 1;
    if (self->_month == 0) {
        self->_year -= 1;
        self->_month = 12;
    }
    [self updateTitle];
}

- (void)refresh {
    [self->cache removeAllObjects];
    [self setNeedsDisplay:true];
}

- (IBAction)endLoading:(id __unused)sender {
    [self->progress stopAnimation:self];
    [self setNeedsDisplay:true];
}

//NSRange daysInMonth(int year, int month) {
//    NSDateComponents* comps = [[NSDateComponents alloc] init];
//    [comps setDay:1];
//    [comps setMonth:month];
//    [comps setYear:year];
//    
//    NSCalendar *calendar = [NSCalendar currentCalendar];
//    NSDate* monthDate = [calendar dateFromComponents:comps];
//    return [calendar rangeOfUnit:NSDayCalendarUnit
//                          inUnit:NSMonthCalendarUnit
//                         forDate:monthDate];
//}

- (void)loadDataThread:(NSArray*)params {
    @autoreleasepool {
        self->loadingThread = [NSThread currentThread];
        self->loading = true;
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self->progress startAnimation:self];
        });
        
        int year = [[params objectAtIndex:0] intValue];
        int month = [[params objectAtIndex:1] intValue];
        
        NSArray* month_calendar = monthcalendar(year, month);
        for (int y = 0; y != month_calendar.count; y++) {
            NSArray* week = [month_calendar objectAtIndex:y];
            for (int x = 0; x != week.count; x++) {
                int day = [[week objectAtIndex:x] intValue];
                if (day != 0) {
                    // make some weak attempt at trying to detect that some other thread has cleared the cache and started another thread
                    if (self->loadingThread != [NSThread currentThread]) {
                        //print 'another loading thread detected, bailing'
                        return;
                    }
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        NSString* key = date_to_key(year, month, day);
                        Waker_AppDelegate* app_delegate = (Waker_AppDelegate*)[[NSApplication sharedApplication] delegate];
                        NSManagedObject* rule = get_rule(app_delegate, year, month, day);
                        if (rule == nil) {
                            [self->cache removeObjectForKey:key];
                        }
                        else {
                            [self->cache setObject:rule forKey:key];
                        }
                    });
                }
            }
        }
        [self performSelectorOnMainThread:@selector(endLoading:) withObject:self waitUntilDone:false];
        self->loading = false;
    }
}

- (void)drawRect:(NSRect)in_rect {
    NSDate* now = [NSDate new];

    int year = self->_year;
    int month = self->_month;

    if ([self->cache objectForKey:date_to_key(year, month, 1)] == nil) {
        [NSThread detachNewThreadSelector:@selector(loadDataThread:) toTarget:self withObject:@[[NSNumber numberWithInt:year], [NSNumber numberWithInt:month]]];
        return;
    }
    int weekday_text_height = 15;
    in_rect.size.height -= weekday_text_height;
    NSArray* month_calendar = monthcalendar(year, month);
    NSSize cell_size = NSMakeSize(in_rect.size.width / 7, in_rect.size.height / month_calendar.count);
    // week titles
    NSMutableParagraphStyle* centeredParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    [centeredParagraphStyle setAlignment:NSTextAlignmentCenter];
    for (NSNumber* x in @[@0, @1, @2, @3, @4, @5, @6]) {
        NSString* day = [weekday_to_string() objectForKey:x];
        NSRect rect = NSMakeRect(
                                 cell_size.width * [x intValue],
                                 in_rect.origin.x + in_rect.size.height,
                                 cell_size.width,
                                 weekday_text_height);
        [day drawInRect:rect withAttributes:@{NSForegroundColorAttributeName: [NSColor grayColor], NSParagraphStyleAttributeName: centeredParagraphStyle}];
    }
    in_rect.size.height -= 5;
    // day data
    NSColor *todayColor = isDarkMode()? [NSColor colorWithWhite:1.0 alpha:0.2] : [NSColor colorWithDeviceRed:0.9 green:0.9 blue:1 alpha:1];
    NSColor *otherDayColor = isDarkMode() ? [NSColor colorWithWhite:1.0 alpha:0.05] : [NSColor colorWithWhite:0.0 alpha:0.05];
    for (int y = 0; y != month_calendar.count; y++) {
        NSArray* week = [month_calendar objectAtIndex:y];
        for (int x = 0; x != week.count; x++) {
            int day = [[week objectAtIndex:x] intValue];
            if (day != 0) {
                NSRect rect = NSMakeRect(
                                         cell_size.width * x,
                                         in_rect.origin.x - cell_size.height * (y + 1) + in_rect.size.height,
                                         cell_size.width,
                                         cell_size.height);
                rect = NSInsetRect(rect, 2, 2);
                BOOL is_today = year == now.year && month == now.month && day == now.day;
                fillRect(rect, is_today? todayColor : otherDayColor);
                NSString* key = date_to_key(year, month, day);
                NSManagedObject* item = [self->cache objectForKey:key];
                if (item == nil) {
                    continue;
                }
                fillRect(NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, 20), IntToNSColor([[item color] intValue]));

                rect.origin.x += 3;
                rect.size.width -= 3;
                [[NSString stringWithFormat:@"%d", day] drawInRect:rect withAttributes:@{NSForegroundColorAttributeName: [NSColor textColor]}];
                rect.origin.x += 2;
                rect.size.height -= 14;
                if (item != nil) {
                    if (([item name] != nil)) {
                        [[NSString stringWithString:[item name]] drawInRect:rect withAttributes:@{NSParagraphStyleAttributeName: centeredParagraphStyle, NSForegroundColorAttributeName: [NSColor textColor]}];
                    }
                    if ([item time] != nil) {
                        rect.size.height -= 38;
                        rect.size.width -= 4;
                        rect.origin.y += 21;
                        NSFont* font = [NSFont fontWithName:@"Geneva" size:MIN(rect.size.height - 4, rect.size.width / 3)];
                        NSDictionary* attributes = @{NSFontAttributeName: font, NSParagraphStyleAttributeName: centeredParagraphStyle, NSForegroundColorAttributeName: [NSColor textColor]};
                        NSString* timeString = [NSString stringWithString:[item time]];
                        NSSize size = [timeString sizeWithAttributes:attributes];
                        rect.origin.y -= rect.size.height / 2 - size.height / 2;
                        [[NSString stringWithString:timeString] drawInRect:rect withAttributes:attributes];
                    }
                }
            }
        }
    }
}

@end
