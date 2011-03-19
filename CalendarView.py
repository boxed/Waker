from objc import YES, NO, IBAction, IBOutlet
from Foundation import *
from AppKit import *
import datetime
import calendar
from waker import *
from transformers import IntToNSColor, NSDateFromString

#calendar.setfirstweekday(NSCalendar.currentCalendar().firstWeekday())
def drawRect(r):
    bp = NSBezierPath.bezierPathWithRect_(r)
    color = NSColor.lightGrayColor()
    color.set()
    bp.stroke()

def fillRect(r, color):
    bp = NSBezierPath.bezierPathWithRect_(r)
    color.set()
    bp.fill()

class CalendarView(NSView):
    cache = {}
    
    title = IBOutlet()
    progress = IBOutlet()
    
    def awakeFromNib(self):
        import datetime
        now = datetime.datetime.now()
        self.year = now.year
        self.month = now.month
        self.progress.stopAnimation_(self)
        self.updateTitle()
        self.loading = False
        self.loadingThread = None
        
    def updateTitle(self):
        self.setNeedsDisplay_(YES)
        self.title.setStringValue_('Preview of %s %s' % (month_to_string[self.month], self.year))
    
    @IBAction
    def nextMonth_(self, sender):
        self.month += 1
        if self.month == 13:
            self.year += 1
            self.month = 1
        self.updateTitle()

    @IBAction
    def previousMonth_(self, sender):
        self.month -= 1
        if self.month == 0:
            self.year -= 1
            self.month = 12
        self.updateTitle()
    
    def refresh(self):
        self.cache = {}
        self.setNeedsDisplay_(True)
        
    def endLoading_(self, sender):
        self.progress.stopAnimation_(self)
        self.setNeedsDisplay_(True)

    def loadDataThread_(self, params):
        pool = NSAutoreleasePool.alloc().init()
        self.loadingThread = NSThread.currentThread()
        self.loading = True
        self.progress.startAnimation_(self)
        year, month, month_calendar = params
        for y, week in enumerate(month_calendar):
            for x, day in enumerate(week):
                if day != 0:
                    # make some weak attempt at trying to detect that some other thread has cleared the cache and started another thread
                    if self.loadingThread != NSThread.currentThread():
                        #print 'another loading thread detected, bailing'
                        return
                    key = (year, month, day)
                    self.cache[key] = get_rule(NSApplication.sharedApplication().delegate(), year, month, day)
        self.performSelectorOnMainThread_withObject_waitUntilDone_(self.endLoading_, self, False)
        self.loading = False
    
    def drawRect_(self, in_rect):
        today = datetime.datetime.now()
        year = self.year
        month = self.month
        month_calendar = calendar.monthcalendar(year, month)
        if (year, month, 1) not in self.cache:
            NSThread.detachNewThreadSelector_toTarget_withObject_(self.loadDataThread_, self, (year, month, month_calendar))
            return
        
        weekday_text_height = 15
        in_rect.size.height -= weekday_text_height

        cell_size = NSSize(in_rect.size.width/len(month_calendar[0]), in_rect.size.height/len(month_calendar))
        
        # week titles
        centeredParagraphStyle = NSMutableParagraphStyle.alloc().init()
        centeredParagraphStyle.setAlignment_(NSCenterTextAlignment)
        for x, day in enumerate(weekday_to_string):
            rect = NSRect(
                NSPoint(cell_size.width*x, in_rect.origin.x+in_rect.size.height), 
                NSSize(cell_size.width, weekday_text_height))
            NSString.stringWithString_(weekday_to_string[day].title()).drawInRect_withAttributes_(rect, {NSForegroundColorAttributeName:NSColor.grayColor(), NSParagraphStyleAttributeName:centeredParagraphStyle}) # centered!
            
        in_rect.size.height -= 5
        
        # day data
        for y, week in enumerate(month_calendar):
            for x, day in enumerate(week):
                if day != 0:
                    rect = NSRect(
                        NSPoint(cell_size.width*x, in_rect.origin.x-cell_size.height*(y+1)+in_rect.size.height), 
                        NSSize(cell_size.width, cell_size.height))
                    rect = NSInsetRect(rect, 2, 2)
                    fillRect(rect, NSColor.colorWithDeviceRed_green_blue_alpha_(0.9, 0.9, 1, 1) if (year, month, day) == (today.year, today.month, today.day) else NSColor.whiteColor())

                    key = (year, month, day)
                    try:
                        item = self.cache[key]
                    except KeyError:
                        continue
                    if item:
                        fillRect(NSRect(rect.origin, NSSize(rect.size.width, 20)), IntToNSColor(item.color()))
                    rect.origin.x += 3
                    rect.size.width -= 3
                    NSString.stringWithString_(str(day)).drawInRect_withAttributes_(rect, {NSForegroundColorAttributeName:NSColor.grayColor()})
                    
                    rect.origin.x += 2
                    rect.size.height -= 14
                    
                    if item is not None:
                        if item.name() is not None:
                            NSString.stringWithString_(item.name()).drawInRect_withAttributes_(rect, {NSParagraphStyleAttributeName:centeredParagraphStyle})
                        if item.time() is not None:
                            rect.size.height -= 38
                            rect.size.width -= 4
                            rect.origin.y += 21
                            font = NSFont.fontWithName_size_('Geneva', min(rect.size.height-4, rect.size.width/3))
                            attributes = {NSFontAttributeName:font, NSParagraphStyleAttributeName:centeredParagraphStyle}
                            timeString = NSString.stringWithString_(item.time())
                            size = timeString.sizeWithAttributes_(attributes)
                            rect.origin.y -= rect.size.height/2-size.height/2
                            NSString.stringWithString_(timeString).drawInRect_withAttributes_(rect, attributes)