# this file is based on curia/__init__.py
from datetime import time, datetime, timedelta
from time import strptime, strftime

def _(foo):
	return foo

def split_and_trim(s, separator=','):
    if s == '':
        return []
    
    result = []
    for x in s.split(','):
        foo = x.strip()
        if foo != '':
            result.append(foo)
    return result

def date_from_string(string):
    try:
        return time(*strptime(string, '%Y-%m-%d %H:%M:%S')[:3])
    except:
        return time(*strptime(string, '%Y-%m-%d')[:3])

def datetime_from_string(string):
    try:
        string, dot, microseconds = string.partition('.')
        microseconds = int(microseconds.rstrip("Z") or '0')
        return datetime(*strptime(string, '%Y-%m-%d %H:%M:%S')[:6])+timedelta(microseconds=microseconds)
    except:
        pass
    try:
        return datetime(*strptime(string, '%Y-%m-%d %H:%M')[:6])
    except:
        return datetime(*strptime(string, '%Y-%m-%d')[:3])
    
def start_of_day(reference_date):
    return datetime(reference_date.year, reference_date.month, reference_date.day)

def first_of_next_month(reference_date):
    if reference_date.month == 12: 
        return datetime(reference_date.year+1, 1, 1);
    else:
        return datetime(reference_date.year, reference_date.month+1, 1);

def first_of_previous_month(reference_date):
    if reference_date.month == 1: 
        return datetime(reference_date.year-1, 12, 1);
    else:
        return datetime(reference_date.year, reference_date.month-1, 1);

def first_day_of_month(reference_date):
    return datetime(reference_date.year, reference_date.month, 1)
    
def relative_date_formatting(date, reference_date=None, show_seconds=False, show_time_of_day=False):
    if not show_time_of_day and show_seconds:
        raise 'show_seconds can not be True if show_time_of_day is False'
    if reference_date == None:
        reference_date = datetime.now()
    if reference_date == date:
        return _('now')

    diff = date - reference_date

    time_formatting = ''

    if show_seconds:
        time_formatting = '%H:%M:%S'
    elif show_time_of_day or abs(date.toordinal() - reference_date.toordinal()) <= 1:
        time_formatting = '%H:%M'
    
    if date.toordinal() == reference_date.toordinal():
        s = ''

        if date > reference_date: # in future
            s = _('in %s') % s
           
        diff = abs(diff)
        if diff >= timedelta(hours=1):
            hours = diff.seconds/60/60
            s += _('%s h ') % hours
        if diff >= timedelta(minutes=1):
            minutes = diff.seconds/60 % 60
            s += _('%s min ') % minutes
        if diff < timedelta(minutes=1):
            s += _('%s s ') % diff.seconds

        if date < reference_date: # in the past
            s = _('%sago') % s
        
        return s
    if date.toordinal() - reference_date.toordinal() == -1:
        return _('yesterday at %s') % strftime(time_formatting, date.timetuple())
    elif date.toordinal() - reference_date.toordinal() == 1:
        return _('tomorrow at %s') % strftime(time_formatting, date.timetuple())
    elif date.year != reference_date.year:
        return strftime('%d %b %Y '+time_formatting, date.timetuple())
    else:
        return strftime('%d %b '+time_formatting, date.timetuple())
            
def relative_date_formatting_unit_test():
    ref = datetime(1980, 4, 17, 11)
    print 'now: '+relative_date_formatting(datetime(1980, 4, 17, 11), ref) # now

    print '- future times -'
    print 'in 5s: '+relative_date_formatting(ref+timedelta(seconds=5), ref, False, False) # in 5 seconds
    print 'in 3m: '+relative_date_formatting(ref+timedelta(minutes=3), ref, False, False) # in 3 minutes
    print 'in almost 1h: '+relative_date_formatting(ref+timedelta(seconds=60*60-1), ref, False, False) # in 2 hours
    print 'in more than 1h: '+relative_date_formatting(ref+timedelta(seconds=60*60+1), ref, False, False) # in 2 hours
    print 'in 2h: '+relative_date_formatting(ref+timedelta(hours=2), ref, False, False) # in 2 hours
    print 'today at 10: '+relative_date_formatting(datetime(1980, 4, 17, 10), ref, False, False) # today at 10
    print 'tomorrow: '+relative_date_formatting(datetime(1980, 4, 18, 10, 55), ref, False, False) # tomorrow
    print 'tomorrow 2: '+relative_date_formatting(datetime(1980, 4, 18, 11, 5), ref, False, False) # tomorrow
    print 'specific date same year and same month: '+relative_date_formatting(datetime(1980, 4, 23), ref, False, False) # specific date
    print 'specific date same year different month: '+relative_date_formatting(datetime(1980, 5, 21), ref, False, False) # specific date
    print 'in 1 year: '+relative_date_formatting(datetime(1981, 4, 17, 11), ref, False, False) # in one year

    print '- past times -'
    print '5s ago: '+relative_date_formatting(ref-timedelta(seconds=5), ref, False, False) # in 5 seconds
    print '3m ago: '+relative_date_formatting(ref-timedelta(minutes=3), ref, False, False) # in 3 minutes
    print '2h ago: '+relative_date_formatting(ref-timedelta(hours=2), ref, False, False) # in 2 hours
    print 'yesterday: '+relative_date_formatting(datetime(1980, 4, 16, 10, 55), ref, False, False) # yesterday
    print 'yesterday 2: '+relative_date_formatting(datetime(1980, 4, 16, 11, 5), ref, False, False) # yesterday
    print 'before midnight: '+relative_date_formatting(datetime(1980, 4, 16, 23, 59, 59), ref, False, False) # before midnight
    print 'midnight: '+relative_date_formatting(datetime(1980, 4, 17, 0, 0, 0), ref, False, False) # midnight
    print 'after midnight: '+relative_date_formatting(datetime(1980, 4, 17, 0, 0, 1), ref, False, False) # after midnight
    print 'specific date past year and same month: '+relative_date_formatting(datetime(1970, 4, 23), ref, False, False) # specific date
    print '1 year ago: '+relative_date_formatting(datetime(1979, 4, 17, 11), ref, False, False) # one year ago
    print '2 hours ago: '+relative_date_formatting(ref-timedelta(hours=2), ref, False, False) # 2 hours ago

def relative_pair_date_formatting(date_start, date_end, reference_date=None, show_seconds=False):
    if reference_date == None:
        reference_date = datetime.now()
        
    if date_start == date_end:
        return relative_date_formatting(date_start, reference_date)
    elif date_start.year == date_end.year and date_start.month == date_end.month and date_start.day == date_end.day:
        if show_seconds:
            time_formatting = '%H:%M:%S'
        else:
            time_formatting = '%H:%M'

        return relative_date_formatting(date_start, reference_date) + ' to '+strftime(time_formatting, date_end.timetuple())
    else:
        return relative_date_formatting(date_start, reference_date) + ' to '+relative_date_formatting(date_end, reference_date)

def relative_pair_date_formatting_unit_test():
    ref = datetime(1980, 4, 17)
    print relative_date_formatting(datetime(1980, 4, 17, 10), ref)
    print 'today from 10 to 10: '+relative_pair_date_formatting(datetime(1980, 4, 17, 10), datetime(1980, 4, 17, 10), ref)
    print 'today from 10 to 13: '+relative_pair_date_formatting(datetime(1980, 4, 17, 10), datetime(1980, 4, 17, 13), ref)
    print 'today from 10 to tomorrow 13: '+relative_pair_date_formatting(datetime(1980, 4, 17, 10), datetime(1980, 4, 18, 13), ref)
    print 'today from 10 to specific date: '+relative_pair_date_formatting(datetime(1980, 4, 17, 10), datetime(1980, 6, 17, 13), ref)
    print 'from specific date to specific date: '+relative_pair_date_formatting(datetime(1980, 5, 17, 10), datetime(1980, 6, 17, 13), ref)

if __name__ == '__main__':
    relative_date_formatting_unit_test()
    #relative_pair_date_formatting_unit_test()
    
def split_and_honor_quotation_marks(cmdline):
    """
    Translate a command line string into a list of arguments, using
    using the same rules as the MS C runtime:

    1) Arguments are delimited by white space, which is either a
       space or a tab.
    
    2) A string surrounded by double quotation marks is
       interpreted as a single argument, regardless of white space
       contained within.  A quoted string can be embedded in an
       argument.

    3) A double quotation mark preceded by a backslash is
       interpreted as a literal double quotation mark.

    4) Backslashes are interpreted literally, unless they
       immediately precede a double quotation mark.

    5) If backslashes immediately precede a double quotation mark,
       every pair of backslashes is interpreted as a literal
       backslash.  If the number of backslashes is odd, the last
       backslash escapes the next double quotation mark as
       described in rule 3.
    """

    # See
    # http://msdn.microsoft.com/library/en-us/vccelng/htm/progs_12.asp

    # Step 1: Translate all literal quotes into QUOTE.  Justify number
    # of backspaces before quotes.
    tokens = []
    bs_buf = ""
    QUOTE = 1 # \", literal quote
    for c in cmdline:
        if c == '\\':
            bs_buf += c
        elif c == '"' and bs_buf:
            # A quote preceded by some number of backslashes.
            num_bs = len(bs_buf)
            tokens.extend(["\\"] * (num_bs//2))
            bs_buf = ""
            if num_bs % 2:
                # Odd.  Quote should be placed literally in array
                tokens.append(QUOTE)
            else:
                # Even.  This quote serves as a string delimiter
                tokens.append('"')

        else:
            # Normal character (or quote without any preceding
            # backslashes)
            if bs_buf:
                # We have backspaces in buffer.  Output these.
                tokens.extend(list(bs_buf))
                bs_buf = ""

            tokens.append(c)

    # Step 2: split into arguments
    result = [] # Array of strings
    quoted = False
    arg = [] # Current argument
    tokens.append(" ")
    for c in tokens:
        if c == '"':
            # Toggle quote status
            quoted = not quoted
            arg.append('"')
        elif c == QUOTE:
            arg.append('"')
        elif c in (' ', '\t'):
            if quoted:
                arg.append(c)
            else:
                # End of argument.  Output, if anything.
                if arg:
                    result.append(''.join(arg))
                    arg = []
        else:
            # Normal character
            arg.append(c)
    
    return result
       
# from http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/194371
# changes made: base on unicode instead of str
# renamed from iStr to CaseInsentiveString
class CaseInsentiveString(unicode):
    """Case insensitive strings class.
    Performs like str except comparisons are case insensitive."""

    def __init__(self, strMe):
        str.__init__(self, strMe)
        self.__lowerCaseMe = unicode(strMe).lower()

    def __repr__(self):
        return "CaseInsentiveString(%s)" % str.__repr__(self)

    def __eq__(self, other):
        return self.__lowerCaseMe == other.lower()

    def __lt__(self, other):
        return self.__lowerCaseMe < other.lower()

    def __le__(self, other):
        return self.__lowerCaseMe <= other.lower()

    def __gt__(self, other):
        return self.__lowerCaseMe > other.lower()

    def __ne__(self, other):
        return self.__lowerCaseMe != other.lower()

    def __ge__(self, other):
        return self.__lowerCaseMe >= other.lower()

    def __cmp__(self, other):
       try:
            return cmp(self.__lowerCaseMe, other.lower())
       except:
            return cmp(self.__lowerCaseMe, other)
            
    def __hash__(self):
        return hash(self.__lowerCaseMe)

    def __contains__(self, other):
        return other.lower() in self.__lowerCaseMe

    def count(self, other, *args):
        return str.count(self.__lowerCaseMe, other.lower(), *args)

    def endswith(self, other, *args):
        return str.endswith(self.__lowerCaseMe, other.lower(), *args)

    def find(self, other, *args):
        return str.find(self.__lowerCaseMe, other.lower(), *args)

    def index(self, other, *args):
        return str.index(self.__lowerCaseMe, other.lower(), *args)

    def lower(self):   # Courtesy Duncan Booth
        return self.__lowerCaseMe

    def rfind(self, other, *args):
        return str.rfind(self.__lowerCaseMe, other.lower(), *args)

    def rindex(self, other, *args):
        return str.rindex(self.__lowerCaseMe, other.lower(), *args)

    def startswith(self, other, *args):
        return str.startswith(self.__lowerCaseMe, other.lower(), *args)