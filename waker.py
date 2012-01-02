from Cocoa import *
from CalendarStore import *
import calendar
import datetime
import time
from datetime import tzinfo, timedelta

weekday_to_string = {
    0: 'monday', 
    1: 'tuesday', 
    2: 'wednesday', 
    3: 'thursday', 
    4: 'friday', 
    5: 'saturday', 
    6: 'sunday', 
}

month_to_string = {
    1: 'January',
    2: 'February',
    3: 'March',
    4: 'April',
    5: 'May',
    6: 'June',
    7: 'July',
    8: 'August',
    9: 'September',
    10: 'October',
    11: 'November',
    12: 'December',
}

class NSTimeZone_local_tzinfo(tzinfo):
    def __init__(self, nstimezone):
        self.nstimezone = nstimezone
    def dst(self, date):
        return timedelta(seconds=self.nstimezone.secondsFromGMT())
    def tzname(self):
        return self.nstimezone.localizedName_locale_(NSTimeZoneNameStyleShortStandard, None)
    def utcoffset(self, date):
        return timedelta(seconds=self.nstimezone.secondsFromGMT())

class NSTimeZone_tzinfo(tzinfo):
    def __init__(self):#, nstimezone):
        #self.nstimezone = nstimezone
        self.tzid = 'GMT'
    def dst(self, date):
        #return timedelta(seconds=self.nstimezone.secondsFromGMT())
        return timedelta() # return nothing, to remove time zone handling
    def tzname(self):
        #return self.nstimezone.localizedName_locale_(NSTimeZoneNameStyleShortStandard, None)
        return self.tzid
    def utcoffset(self, date):
        #return timedelta(seconds=self.nstimezone.secondsFromGMT())
        return timedelta() # return nothing, to remove time zone handling

def NSDateToDatetime(nsdate, use_local=False):
    if nsdate is None:
        return None
    assert(isinstance(nsdate, NSDate))
    # Convert a 8:00 GMT datetime to a 8:00 local time zone object. Waker has GMT internally and converts when calling out.        # The commented lines are the implementation for handling timezones "correctly", meaning 8:00 GMT == 9:00 GMT+1. We don't want that but I've left the code for it for completeness and so you can compare it.
    timezoneOffset = str(nsdate)[-5:]
    neg = timezoneOffset[0] == '-'
    timezoneOffset = int(timezoneOffset[1:3])*60*60+int(timezoneOffset[-2:])*60
    if neg:
        timezoneOffset = -timezoneOffset
    tz = NSTimeZone_local_tzinfo() if use_local else NSTimeZone_tzinfo()
    return datetime.datetime.fromtimestamp(nsdate.timeIntervalSince1970()+timezoneOffset, tz=tz)

def datetimeToNSDate(dt, use_local=False):
    assert(isinstance(dt, datetime.datetime))
    #tzinfo = dt.tzinfo
    #if tzinfo is None:# or tzinfo is ICUtzinfo.floating:
    #    nstimezone = NSTimeZone.localTimeZone()
    #else:
    #   nstimezone = NSTimeZone.timeZoneWithName_(tzinfo.tzid)
    nstimezone = NSTimeZone.localTimeZone() if use_local else NSTimeZone.timeZoneWithName_('GMT')
    result = NSCalendarDate.dateWithYear_month_day_hour_minute_second_timeZone_(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, nstimezone)
    return result

def datetimeToCFAbsoluteTime(inTime):
    assert(isinstance(inTime, datetime.datetime))
    # Convert a 8:00 GMT datetime to a 8:00 local time zone object. Waker has GMT internally and converts when calling out.
    import time
    reference = datetime.datetime(2001, 1, 1)
    d = inTime-reference
    gmt = time.gmtime()
    local = time.localtime()
    diff = (gmt.tm_hour*60*60+gmt.tm_min*60)-(local.tm_hour*60*60+local.tm_min*60)
    if diff > 60*60*12: # we're at the border between days
        diff -= 60*60*24
    if diff < -60*60*12: # we're at the border between days
        diff += 60*60*24
    #print 'datetimeToCFAbsoluteTime diff',diff
    return d.days*86400.0+d.seconds+d.microseconds/1000000.0+diff
    
def events_of_day(year, month, date):
    store = CalCalendarStore.defaultCalendarStore()
    day = datetime.datetime(year, month, date)
    tomorrow = day+datetime.timedelta(1)
    startDate = datetimeToNSDate(day+timedelta(seconds=1), use_local=True)
    endDate = datetimeToNSDate(tomorrow-timedelta(seconds=1), use_local=True)
    allEventsPredicate = CalCalendarStore.eventPredicateWithStartDate_endDate_calendars_(startDate, endDate, store.calendars())
    events = store.eventsWithPredicate_(allEventsPredicate)
    #print 'events of', day
    #print unicode(events).encode('ascii', 'ignore')
    return events

def matches_rule(events, day, rule):
    if rule.predicate() is None:
        return True
    try:
        day_of_week = weekday_to_string[day.weekday()]
        for event in events:
            if  NSPredicate.predicateWithFormat_(rule.predicate()).evaluateWithObject_({
                'day': day_of_week, 
                'title': event.title(), 
                'location': event.location(), 
                'notes': event.notes(), 
                'url': event.url(),
                }):
                return True
        return NSPredicate.predicateWithFormat_(rule.predicate()).evaluateWithObject_({'day': day_of_week})
    except:
        NSLog('Warning: matches_rule failed, ignoring...')
        return False

def get_rule(settings, year, month, date):
    day = datetime.datetime(year, month, date)
    events = events_of_day(year, month, date)
    for rule in settings.rules():
        if matches_rule(events, day, rule):
            return rule
    return None

def get_classification(settings, year, month, date):
    rule = get_rule(settings, year, month, date)
    if rule is None:
        return None
    return rule.name()
    
def get_alarm_time_and_rule(settings, year, month, date):
    day = datetime.datetime(year, month, date)
    events = events_of_day(year, month, date)
    for rule in settings.rules():
        if matches_rule(events, day, rule):
            if rule.time() is None:
                return None, rule.name()
            else:
                rule_time = datetime.datetime.strptime(rule.time(), '%H:%M')
                return datetime.datetime(year, month, date, rule_time.hour, rule_time.minute), rule.name()
    return None, None
        
def get_next_alarm_time_and_rule(settings, in_reference_date = None):
    if in_reference_date == None:
        in_reference_date = datetime.datetime.now()
        reference_date = in_reference_date
    else:
        assert(isinstance(in_reference_date, datetime.datetime))
        reference_date = datetime.datetime(in_reference_date.year, in_reference_date.month, in_reference_date.day)+datetime.timedelta(1) # skip the rest of the day
    next_alarm, rule = get_alarm_time_and_rule(settings, reference_date.year, reference_date.month, reference_date.day)
    # TODO: prevent infinite loops here
    lookahead_limit = in_reference_date+datetime.timedelta(days=3*30)
    while reference_date < lookahead_limit and (next_alarm is None or next_alarm < in_reference_date):
        reference_date += datetime.timedelta(days=1)
        next_alarm, rule = get_alarm_time_and_rule(settings, reference_date.year, reference_date.month, reference_date.day)
    return next_alarm, rule

if __name__ == '__main__':
    class Rule:
            def __init__(self, priority, name, predicate, time):
                self._priority, self._name, self._predicate, self._time = priority, name, predicate, datetimeToNSDate(time) if time is not None else None
            
            def priority(self):
                return self._priority
                
            def name(self):
                return self._name
                
            def predicate(self):
                return self._predicate
                
            def time(self):
                return self._time
            
    class Settings:
        def rules(self):
            return [
                Rule(0, 'abroad', 'title BEGINSWITH "abroad"', None),
                Rule(1, 'vacation', 'title CONTAINS "semester" OR title CONTAINS "vacation"', datetime.datetime(1, 1, 1, 11, 00)),
                Rule(2, 'workday', 'day !=[c] "Sunday" AND day !=[c] "Saturday"', datetime.datetime(1, 1, 1, 7, 50)),
                Rule(3, 'weekend', 'day ==[c] "Saturday" OR day ==[c] "Sunday"', datetime.datetime(1, 1, 1, 11, 30)),
            ]
    settings = Settings()
    
    def print_classification_of_month(year, month):
        for date in range(1, calendar.monthrange(year, month)[1]+1):
            foo = datetime.datetime(year, month, date)
            print year, month, date, get_classification(settings, year, month, date), '(', get_alarm_time_and_rule(settings, year, month, date), '-', get_next_alarm_time_and_rule(settings, foo) ,')', '-', ', '.join([x.title() for x in events_of_day(year, month, date)])
    
    print_classification_of_month(2009, 8)