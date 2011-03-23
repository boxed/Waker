# coding=UTF-8
from objc import YES, NO, IBAction, IBOutlet
from Foundation import *
from AppKit import *
import re
from fuzzy_dict import FuzzyDict

_NSDateFromString_units = FuzzyDict({
    'second':1,
    'minute':60,
    'hour':60*60,
    'day':60*60*24,
}, cutoff=0.1)

class DidNotUnderstandException:
    def __repr__(self):
        return "I'm sorry, I didn't understand that"

def NSDateFromString(str):
    if str.startswith('in '):
        str = str.strip()
        m = re.match(r'in (?P<num>\d+)\s*(?P<unit>.*)', str)
        if m:
            num, unit = float(m.groupdict()['num']), m.groupdict()['unit']
            global _NSDateFromString_units
            from datetime import datetime, timedelta
            from waker import datetimeToNSDate
            return datetimeToNSDate(datetime.now()+timedelta(seconds=num*_NSDateFromString_units[unit]))
        raise DidNotUnderstandException()
    date = NSDate.dateWithNaturalLanguageString_(str)
    # now convert it to GMT for the internal processing
    from waker import NSDateToDatetime, datetimeToNSDate
    tmp = NSDateToDatetime(date)
    if tmp is None:
        raise DidNotUnderstandException()
    return datetimeToNSDate(tmp)

#2011-01-08 09:00:00 +0100
def test():
    print '--- tests ---'
    import datetime
    from waker import NSTimeZone_tzinfo, datetimeToNSDate, NSDateToDatetime
    # sanity check 
    test_first_jan_2010_8_oclock_datetime = datetime.datetime(2011, 1, 1, 8, 0, tzinfo=NSTimeZone_tzinfo())
    assert(str(test_first_jan_2010_8_oclock_datetime).endswith('08:00:00+00:00'))
    
    # test datetimeToNSDate
    assert(str(datetimeToNSDate(test_first_jan_2010_8_oclock_datetime)).endswith('08:00:00 +0000'))
    
    # test NSDateToDatetime
    nowNSDate = NSDate.date()
    foo = str(nowNSDate)
    bar = str(NSDateToDatetime(nowNSDate))
    #print 'foo', foo
    #print 'bar', bar
    assert(foo[:-6] == bar[:-13])

    #print test_first_jan_2010_8_oclock_datetime
    #print datetimeToNSDate(test_first_jan_2010_8_oclock_datetime)
    print NSDateToDatetime(datetimeToNSDate(test_first_jan_2010_8_oclock_datetime))
    assert(str(NSDateToDatetime(datetimeToNSDate(test_first_jan_2010_8_oclock_datetime))).endswith('08:00:00+00:00'))

    # test NSDateFromString (this uses both the functions above)
    test_first_jan_2010_8_oclock = NSDateFromString('8:00')
    assert(str(test_first_jan_2010_8_oclock).endswith('08:00:00 +0000'))
    
    print '------------'
#test()

class DateTransformer(NSValueTransformer): 
    def transformedValueClass(self):
        return NSString
    transformedValueClass = classmethod(transformedValueClass)
    
    def allowsReverseTransformation(self):
        return YES
    allowsReverseTransformation = classmethod(allowsReverseTransformation)
    
    def transformedValue_(self, value):
        # string in, string out
        if value is None:
            return 'n/a'
        return value
        
    def reverseTransformedValue_(self, value):
        # string in, string out
        if value == 'n/a':
            return None
        return value

class NumberTransformer(NSValueTransformer):
    def transformedValueClass(self):
        return NSNumber
    transformedValueClass = classmethod(transformedValueClass)
    
    def allowsReverseTransformation(self):
        return YES
    allowsReverseTransformation = classmethod(allowsReverseTransformation)
    
    def transformedValue_(self, value):
        return str(value)
        
    def reverseTransformedValue_(self, value):
        if value is None:
            return 0
        return int(value)

class NothingTransformer(NSValueTransformer):
    def transformedValueClass(self):
        return NSString
    transformedValueClass = classmethod(transformedValueClass)
    
    def allowsReverseTransformation(self):
        return YES
    allowsReverseTransformation = classmethod(allowsReverseTransformation)
    
    def transformedValue_(self, value):
        return value
        
    def reverseTransformedValue_(self, value):
        return value
        
def IntToNSColor(value):
    if value is None:
        return NSColor.grayColor()
    return NSColor.colorWithCalibratedRed_green_blue_alpha_(
        ((value & 0xFF0000) >> 16)/255.0, 
        ((value & 0xFF00) >> 8)/255.0, 
        (value & 0xFF)/255.0, 
        1)

class ColorTransformer(NSValueTransformer):
    def transformedValueClass(self):
        return NSColor
    transformedValueClass = classmethod(transformedValueClass)
    
    def allowsReverseTransformation(self):
        return YES
    allowsReverseTransformation = classmethod(allowsReverseTransformation)
    
    def transformedValue_(self, value):
        return IntToNSColor(value)
        
    def reverseTransformedValue_(self, value):
        return int(value.redComponent()*255) << 16 | int(value.greenComponent()*255) << 8 | int(value.blueComponent()*255)

class PredicateTransformer(NSValueTransformer):
    def transformedValueClass(self):
        return NSString
    transformedValueClass = classmethod(transformedValueClass)
    
    def allowsReverseTransformation(self):
        return YES
    allowsReverseTransformation = classmethod(allowsReverseTransformation)
    
    def transformedValue_(self, value):
        if value is None:
            value = 'title CONTAINS ""'
        predicate = NSPredicate.predicateWithFormat_(value)
        if type(predicate) != NSCompoundPredicate:
            predicate = NSCompoundPredicate.andPredicateWithSubpredicates_([predicate])
        return predicate
        
    def reverseTransformedValue_(self, value):
        if value == None:
            return None
        return value.predicateFormat()

class DisableAlarmTransformer(NSValueTransformer):
    def transformedValueClass(self):
        return NSString
    transformedValueClass = classmethod(transformedValueClass)
    
    def allowsReverseTransformation(self):
        return YES
    allowsReverseTransformation = classmethod(allowsReverseTransformation)
    
    def transformedValue_(self, value):
        print 'disable1', value, type(value)
        # NSDate in, string out
        if value is None:
            return True
        return False
        
    def reverseTransformedValue_(self, value):
        print 'disable2', value, type(value)
        if value == False:
            return '8:00'
        return None

class EnableAlarmTransformer(NSValueTransformer):
    def transformedValueClass(self):
        return NSString
    transformedValueClass = classmethod(transformedValueClass)
    
    def allowsReverseTransformation(self):
        return NO
    allowsReverseTransformation = classmethod(allowsReverseTransformation)
    
    def transformedValue_(self, value):
        # NSDate in, string out
        if value is None:
            return False
        return True
        
    def reverseTransformedValue_(self, value):
        if value == True:
            return NSDateFromString('8:00')
        return None

# Create and register value transformers
transformer = DateTransformer.alloc().init()
NSValueTransformer.setValueTransformer_forName_(transformer, u'DateTransformer')
