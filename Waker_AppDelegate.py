# -*- coding: UTF-8 -*-
from objc import YES, NO, IBAction, IBOutlet
from Foundation import *
from AppKit import *
from CoreData import *
import os
import pickle
from time import sleep
from waker import *
from from_curia import *
from PyObjCTools.KeyValueCoding import kvc
from transformers import NSDateFromString, IntToNSColor, DidNotUnderstandException
from CalendarView import *
import datetime

remote_up = 2
remote_down = 4
remote_left = 64
remote_right = 32
remote_playpause = 16

ExceptionRule = 'Exception'
NowExceptionRule = 'User triggered'

# -- COOL FEATURES --
# Use any connected microphones to check if the alarm is actually playing in the room. If not, play the backup alarm over the built in speakers.
# RESEARCH: calling phone numbers as alarm. Coupled with a custom ring tone this becomes very useful. Can lead to a bunch of other features like you have to enter a code to say you are awake otherwise it will keep calling. With voice synth and interpretation this can be especially cool.
# RESEARCH: home automation integration

class FooCell(NSCell):
    def drawWithFrame_inView_(self, cellFrame, controlView):
        bp = NSBezierPath.bezierPathWithRect_(cellFrame)
        IntToNSColor(self.objectValue()).set()
        bp.fill()

def get_user_default(key):
    return NSUserDefaultsController.sharedUserDefaultsController().values().valueForKey_(key)
    
def set_user_default(key, value):
    if isinstance(value, datetime.datetime):
        value = value.strftime('%Y-%m-%d %H:%M:%S')
    NSUserDefaultsController.sharedUserDefaultsController().values().setValue_forKey_(value, key)

def get_itunes():
    import appscript
    import tunes
    return appscript.app('iTunes', terms=tunes)


def is_playing():
    return str(get_itunes().player_state()) == 'k.playing'

class Waker_AppDelegate(NSObject, kvc):
    _managedObjectModel = None
    _persistentStoreCoordinator = None
    _managedObjectContext = None
    next_alarm = None
    next_alarm_rule = None
    remote_control = None
    
    firstRunWindow = IBOutlet()

    window = IBOutlet()
    previewCalendarView = IBOutlet()
    newRuleButton = IBOutlet()
    newRuleTipWindow = IBOutlet()
    newRuleTipView = IBOutlet()
    bridge = IBOutlet()
    
    rules_controller = IBOutlet()
    
    statusBarMenu = IBOutlet()
    statusBarMenuPreviewItem = IBOutlet()
    
    exceptionWindow = IBOutlet()
    exceptionWindowInput = IBOutlet()
    
    aboutWindow = IBOutlet()
    
    predicateEditor = IBOutlet()
    
    alarmWindow = IBOutlet()
    alarmWindowTime = IBOutlet()
    alarmWindowMatchedRule = IBOutlet()
    alarmWindowDay1Title = IBOutlet()
    alarmWindowDay1Text = IBOutlet()
    alarmWindowDay2Title = IBOutlet()
    alarmWindowDay2Text = IBOutlet()
    alarmWindowDay3Title = IBOutlet()
    alarmWindowDay3Text = IBOutlet()
    alarmWindowDay4Title = IBOutlet()
    alarmWindowDay4Text = IBOutlet()
    alarmWindowDay5Title = IBOutlet()
    alarmWindowDay5Text = IBOutlet()
    alarmWindowDay6Title = IBOutlet()
    alarmWindowDay6Text = IBOutlet()
    alarmWindowDay7Title = IBOutlet()
    alarmWindowDay7Text = IBOutlet()
    alarmWindowStopAlarmButton = IBOutlet()
    
    large_type_window = None
    just_woke = False

    _backup_alarm = None
    def get_backup_alarm(self):
        if self._backup_alarm is None:
            NSLog('loading backup alarm')
            self._backup_alarm = NSSound.alloc().initWithContentsOfFile_byReference_(os.path.join(NSBundle.mainBundle().resourcePath(), 'Sonata No. 5 in C Minor, Op. 10 No. 1 - II. Adagio molto.mp3'), FALSE) 
        return self._backup_alarm
    
    def init_speech(self):
        self.recog = NSSpeechRecognizer.alloc().init()
        # recog is an ivar
        self.recog.setCommands_(['sing', 'jump'])
        self.recog.setDelegate_(self)
        self.recog.startListening()
        
    def speechRecognizer_didRecognizeCommand_(self, sender, aCmd):
        print 'recognized',aCmd
    
    def awakeFromNib(self):
        self.rules_controller.setSortDescriptors_([NSSortDescriptor.alloc().initWithKey_ascending_("priority", YES)])
        NSUserDefaults.standardUserDefaults().registerDefaults_({'system_volume':0.7, 'first_run':True, 'snooze_minutes':10})
        NSWorkspace.sharedWorkspace().notificationCenter().addObserver_selector_name_object_(self, self.onSleep_, NSWorkspaceWillSleepNotification, NSWorkspace.sharedWorkspace())
        NSWorkspace.sharedWorkspace().notificationCenter().addObserver_selector_name_object_(self, self.onWake_, NSWorkspaceDidWakeNotification, NSWorkspace.sharedWorkspace())
        self.newRuleTipWindow = MAAttachedWindow.alloc().initWithContentView_attachedToView_onSide_(self.newRuleTipView, self.newRuleButton, 3).retain()
        assert self.newRuleTipWindow

    def applicationDidFinishLaunching_(self, sender):
        #self.init_speech()
        self.disableModelChangedUpdates = False
        self.managedObjectContext() # init context
        self.setup_menu()
        self.bridge.initRights()
        # set up the global timer to call us every 5 seconds
        NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(5, self, self.timer, None, YES)
        
        try:
            self.next_alarm = datetime.datetime.strptime(get_user_default('next_alarm'), '%Y-%m-%d %H:%M:%S')
            self.next_alarm_rule = get_user_default('next_alarm_rule')
        except:
            self.next_alarm = None
            self.next_alarm_rule = None
        NSLog('previous alarm set: %@', self.next_alarm)
        
        if self.next_alarm is None or datetime.datetime.now() > self.next_alarm:
            self.set_next_alarm()
        NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(self, self.calendarChanged_, CalEventsChangedExternallyNotification, CalCalendarStore.defaultCalendarStore())
        if get_user_default('first_run'):
            self.showFirstRunWindow()
        self.bridge.testAbsoluteTimeConversion_(datetimeToCFAbsoluteTime(datetime.datetime.now()))
        self.remote_control = AppleRemote.alloc().initWithDelegate_(self)
        if self.remote_control:
            self.remote_control.setDelegate_(self)
        # debug code
        #self.show_alarm_window()
        #self.showFirstRunWindow()
        #self.openWaker_(self)
        
    def applicationWillBecomeActive_(self, aNotification):
        if self.remote_control:
            self.remote_control.startListening_(self)

    def applicationWillResignActive_(self, aNotification):
        if self.remote_control:
            self.remote_control.stopListening_(self)

    def showFirstRunWindow(self):
        self.firstRunWindow.center()
        self.firstRunWindow.makeKeyAndOrderFront_(self)
        self.firstRunWindow.orderFrontRegardless()
    
    def calendarChanged_(self, sender):
        NSLog('calendarChanged:')
        self.previewCalendarView.refresh()
        self.set_next_alarm()
            
    def rules(self):
        request = NSFetchRequest.alloc().init()
        request.setEntity_(self.managedObjectModel().entitiesByName()['Rule'])
        request.setSortDescriptors_([NSSortDescriptor.alloc().initWithKey_ascending_("priority", YES)])
        for result in self.managedObjectContext().executeFetchRequest_error_(request, None):
            if result:
                for rule in result:
                    yield rule

    def applicationSupportFolder(self):
        paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)
        basePath = paths[0] if (len(paths) > 0) else NSTemporaryDirectory()
        return os.path.join(basePath, "Waker")
        
    def setNextAlarmThread_(self, params):
        pool = NSAutoreleasePool.alloc().init()
        NSThread.currentThread().setName_('setNextAlarmThread')
        next_alarm, rule = params
        from datetime import timedelta
        if next_alarm == None:
            next_alarm, rule = get_next_alarm_time_and_rule(self, self.next_alarm)
        NSLog('comparing %@, %@', self.next_alarm, next_alarm)
        if self.next_alarm is not next_alarm:
            set_user_default('next_alarm', next_alarm)
            set_user_default('next_alarm_rule', rule)
            NSLog('next alarm rule: %@', rule)
            self.next_alarm = next_alarm
            self.next_alarm_rule = rule
            set_user_default('next_alarm', self.next_alarm)
            set_user_default('next_alarm_rule', self.next_alarm_rule)
            NSUserDefaultsController.sharedUserDefaultsController().save_(self)
            self.setWakeup_(self)        

    def set_next_alarm(self, next_alarm=None, rule=None):
        if self.next_alarm_rule != NowExceptionRule and self.next_alarm_rule != ExceptionRule:
            NSLog('set_next_alarm %@, %@', next_alarm, rule)
            self.next_alarm_rule = None
            self.next_alarm = None
            NSThread.detachNewThreadSelector_toTarget_withObject_(self.setNextAlarmThread_, self, (next_alarm, rule))
        else:
            NSLog('ignored set_next_alarm, %s' % self.next_alarm_rule)
    
    def fadeInVolume(self):
        NSThread.detachNewThreadSelector_toTarget_withObject_(self.fadeInVolumeThread_, self, None)
    
    def fadeInVolumeThread_(self, params):
        pool = NSAutoreleasePool.alloc().init()
        NSThread.currentThread().setName_('fadeInVolumeThread')
        NSLog('fadeInVolume')
        from time import sleep
        volume = 0
        step = 0.005
        target = get_user_default('system_volume')
        while True:
            if not self.alarmWindow.isVisible():
                break
            sleep(0.1)
            self.bridge.setVolume_(volume)
            volume += step
            if volume >= target:
                break

    def fadeOutVolume(self):
        NSThread.detachNewThreadSelector_toTarget_withObject_(self.fadeOutVolumeThread_, self, None)
    
    def fadeOutVolumeThread_(self, params):
        pool = NSAutoreleasePool.alloc().init()
        NSThread.currentThread().setName_('fadeOutVolumeThread')
        NSLog('fadeOutVolume')
        from time import sleep
        volume = self.bridge.volume()
        step = 0.005
        target = 0
        while True:
            if not self.alarmWindow.isVisible():
                break
            sleep(0.1)
            self.bridge.setVolume_(volume)
            volume -= step
            if volume <= target:
                break

    def timer(self):
        from datetime import datetime
        if self.next_alarm:
            if datetime.now() > self.next_alarm+timedelta(hours=2):
                NSLog('missed the alarm slot by more than 2 hours, skipping')
                self.set_next_alarm()
                return
            if datetime.now() > self.next_alarm:
                self.play_alarm()
                self.set_next_alarm()
        self.update_menu_preview()
        self.alarmWindowTime.setStringValue_(NSDate.date().descriptionWithCalendarFormat_timeZone_locale_('%H:%M', None, None))
        if self.large_type_window is not None:
            NSLog('cancel large type')
            self.large_type_window.close()
            self.large_type_window = None
            
    @IBAction
    def playAlarmThread_(self, param):
        pool = NSAutoreleasePool.alloc().init()
        import datetime
        ref = datetime.datetime.now()
        try:
            NSThread.currentThread().setName_('playAlarmThread')
            self.iTunes_thread = NSThread.currentThread()
            NSLog('attempting to play iTunes alarm')
            from appscript import app, reference
            itunes = get_itunes()
            masterplaylist = itunes.playlists()[1]
            try:
                masterplaylist.play()
            except reference.CommandError:
                try:
                    masterplaylist = itunes.playlists()[13]
                    masterplaylist.play()
                except Exception, e:
                    NSLog('Exception: %s', str(e))
                    NSLog('iTunes thread failed')
                    # Something has gone really bad, let's just let the backup alarm play.
                    return
            # I need to turn shuffle off, then skip, then turn it on again and skip again to make it re-shuffle.
            # If you just set shuffle and skip a track you'll get the same song every time. Ugh.
            itunes.set(masterplaylist.shuffle, to=0)
            itunes.next_track()
            itunes.set(masterplaylist.shuffle, to=1)
            itunes.next_track()
            # check if alarm was started with a 5 seconds timeout
            while (datetime.datetime.now()-ref).seconds < 5:
                sleep(0.5)
                if is_playing():
                    # timer successfully evaluated
                    NSLog('iTunes is playing!')
                    self.get_backup_alarm().stop()
                    self.iTunes_is_playing = True
                    break
            if self.next_alarm_rule != NowExceptionRule:
                self.skipAlarm_(self)
        except:
            print 'failed to play alarm'
        
        # Wait 1.5 hours. If the computer has been idle for between an hour and an hour and 30 seconds, pause music and sleep.
        # If we've had the screen up for more than 1.5 hours but we didn't hit the 30 second window to sleep the system, exit the loop
        timeSinceAlarmStart = 0
        while timeSinceAlarmStart < 1.5*60*60:
            if not self.alarmWindow.isVisible():
                NSLog('user closed alarm window')
                break
            if timeSinceAlarmStart > 60*60 and timeSinceAlarmStart < 60*60+30 and self.alarmWindow.isVisible():
                NSLog('itunes has been idle for too long, pausing music and sleeping system!')
                itunes = get_itunes()
                itunes.pause()
                self.bridge.sleepSystem()
                break
            sleep(10)
            timeSinceAlarmStart = (datetime.datetime.now()-ref).seconds
                
        NSLog('exiting iTunes thread')
        
    def play_alarm(self):
        self.bridge.setVolume_(0)
        self.iTunes_is_playing = False
        self.show_alarm_window()
        NSLog('starting alarm thread')
        self.iTunes_thread = None
        NSThread.detachNewThreadSelector_toTarget_withObject_(self.playAlarmThread_, self, None)
        NSLog('alarm thread started')
        import datetime
        ref = datetime.datetime.now()
        # check if alarm was started with a timeout
        while (datetime.datetime.now()-ref).seconds < 60:
            sleep(0.5)
            if self.iTunes_is_playing:
                # timer successfully evaluated
                NSLog('iTunes is playing! (2)')
                self.fadeInVolume()
                return
        NSLog('backup alarm!')
        self.iTunes_thread.cancel()
        self.get_backup_alarm().play()
        self.fadeInVolume()
        
    def snooze(self):
        minutes = float(get_user_default('snooze_minutes'))
        self.fadeOutVolume()
        from appscript import app, reference
        itunes = get_itunes()
        itunes.pause()
        NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(int(minutes*60), self, self.play_alarm, None, NO)
        
    def show_alarm_window(self):
        self.alarmWindow.setBackgroundColor_(NSColor.blackColor())
        if self.alarmWindow.isVisible():
            NSLog('Warning! alarm already active but tried to start it anyway')
        self.alarmWindow.orderFrontRegardless()
        self.alarmWindow.toggleFullScreen_(self)
        # TODO: update the day titles and texts
        def events_as_string(calendar):
            return '\n'.join([x.title() for x in events_of_day(calendar.year, calendar.month, calendar.day)])
        weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        calendar = datetime.datetime.now()
        self.alarmWindowDay1Text.setStringValue_(events_as_string(calendar))
        calendar = calendar+datetime.timedelta(days=1)
        self.alarmWindowDay2Text.setStringValue_(events_as_string(calendar))
        calendar = calendar+datetime.timedelta(days=1)
        self.alarmWindowDay3Text.setStringValue_(events_as_string(calendar))
        self.alarmWindowDay3Title.setStringValue_(weekdays[calendar.weekday()])
        calendar = calendar+datetime.timedelta(days=1)
        self.alarmWindowDay4Text.setStringValue_(events_as_string(calendar))
        self.alarmWindowDay4Title.setStringValue_(weekdays[calendar.weekday()])
        calendar = calendar+datetime.timedelta(days=1)
        self.alarmWindowDay5Text.setStringValue_(events_as_string(calendar))
        self.alarmWindowDay5Title.setStringValue_(weekdays[calendar.weekday()])
        calendar = calendar+datetime.timedelta(days=1)
        self.alarmWindowDay6Text.setStringValue_(events_as_string(calendar))
        self.alarmWindowDay6Title.setStringValue_(weekdays[calendar.weekday()])
        calendar = calendar+datetime.timedelta(days=1)
        self.alarmWindowDay7Text.setStringValue_(events_as_string(calendar))
        self.alarmWindowDay7Title.setStringValue_(weekdays[calendar.weekday()])
        self.alarmWindowMatchedRule.setStringValue_(self.next_alarm_rule)
        self.alarmWindowStopAlarmButton.cell().setBackgroundColor_(NSColor.colorWithDeviceWhite_alpha_(0.2, 1.0))
        self.alarmWindowStopAlarmButton.setTextColor_(NSColor.whiteColor())
    
    @IBAction
    def closeAlarmWindow_(self, sender):
        self.alarmWindow.close()
        self.alarmWindow.orderOut_(self)

    def setup_menu(self):
        statusBar = NSStatusBar.systemStatusBar()
        self.statusItem = statusBar.statusItemWithLength_(37)
        self.statusItem.setMenu_(self.statusBarMenu)
        self.statusItem.setHighlightMode_(True)
        self.statusItem.setImage_(NSImage.imageNamed_("menu_item.png"))
        self.statusItem.setAlternateImage_(NSImage.imageNamed_("menu_item_inverted.png"))

    def update_menu_preview(self):
        if self.next_alarm:
            next_alarm_description = str(relative_date_formatting(self.next_alarm))
        else:
            next_alarm_description = 'No alarm set'
        self.statusBarMenuPreviewItem.setTitle_(next_alarm_description)

    def onWake_(self, notification):
        self.just_woke = True
        NSLog('onWake')
    
    def onSleep_(self, notification):
        if self.next_alarm != None:
            # display next alarm time and delay some time to allow the user to see the message
            self.just_woke = False
            from datetime import timedelta, datetime
            foo = self.bridge.QSShowLargeType_('Next alarm: %s' % str(relative_date_formatting(self.next_alarm)))
            NSLog('delaying sleep...')
            for x in xrange(5):
                if self.just_woke or self.bridge.lidClosed():
                    NSLog('just woke!')
                    break
                NSRunLoop.currentRunLoop().runUntilDate_(datetime.now()+timedelta(seconds=1))
            self.large_type_window = foo
            NSLog('done with onSleep')        
    
    def new_rule(self):
        self.managedObjectContext().lock()
        self.managedObjectContext().undoManager().beginUndoGrouping()
        self.managedObjectContext().undoManager().setActionName_('new rule')
        obj = NSEntityDescription.insertNewObjectForEntityForName_inManagedObjectContext_('Rule', self.managedObjectContext())
        obj.setName_('unnamed')
        self.managedObjectContext().undoManager().endUndoGrouping()
        self.managedObjectContext().unlock()
        return obj
        
    def update_tip_window(self):
        if self.rules_controller.arrangedObjects().count() == 0 and self.window.isVisible():
            self.newRuleTipWindow.show_(self)
        else:
            self.newRuleTipWindow.hide_(self)
        
    @IBAction
    def firstRunCreateDefaultRules_(self, sender):
        minutes = 60
        hours = 60*minutes
        self.disableModelChangedUpdates = True
        self.managedObjectContext().lock()
        self.managedObjectContext().undoManager().beginUndoGrouping()
        self.managedObjectContext().undoManager().setActionName_('default rules')
        
        abroad = self.new_rule()
        #obj = NSManagedObject.initWithEntity_insertIntoManagedObjectContext_(self.managedObjectContext().entitiesByName()['Rule'], self.managedObjectContext())
        abroad.setName_('Abroad')
        abroad.setPredicate_('title BEGINSWITH[cd] "abroad"')
        abroad.setPriority_(1)
        abroad.setColor_(0x16FF5D)
        
        vacation = self.new_rule()
        vacation.setName_("Vacation")
        vacation.setPredicate_('title CONTAINS[cd] "vacation"')
        vacation.setPriority_(2)
        vacation.setTime_('11:00')
        vacation.setColor_(0x16FF5D)

        workday = self.new_rule()
        workday.setName_("Workday")
        workday.setPredicate_('day !=[c] "Sunday" AND day !=[c] "Saturday"')
        workday.setPriority_(3)
        workday.setTime_('07:00')
        workday.setColor_(0x9BAAFF)

        weekend = self.new_rule()
        weekend.setName_("Weekend")
        weekend.setPredicate_('day ==[c] "Saturday" OR day ==[c] "Sunday"')
        weekend.setPriority_(4)
        weekend.setTime_('10:00')
        weekend.setColor_(0xFF5B6F)
        
        self.managedObjectContext().undoManager().endUndoGrouping()
        self.managedObjectContext().unlock()
        
        set_user_default('first_run', False)
        self.firstRunWindow.close()
        self.disableModelChangedUpdates = False
        self.openWaker_(self)
        self.objectModelChanged()

    @IBAction
    def firstRunNoDefaultRules_(self, sender):
        set_user_default('first_run', False)
        self.firstRunWindow.close()
        self.openWaker_(self)
        
    @IBAction
    def showExceptionWindow_(self, sender):
        self.exceptionWindow.makeKeyAndOrderFront_(sender)
        self.exceptionWindow.orderFrontRegardless()
        NSApplication.sharedApplication().activateIgnoringOtherApps_(True)
        self.exceptionWindow.fieldEditor_forObject_(YES, self.exceptionWindowInput).setSelectedRange_(NSRange(12, 100))

    @IBAction
    def showAboutWindow_(self, sender):
        self.aboutWindow.center()
        self.aboutWindow.makeKeyAndOrderFront_(sender)
        self.aboutWindow.orderFrontRegardless()
        NSApplication.sharedApplication().activateIgnoringOtherApps_(True)
    
    @IBAction
    def setException_(self, sender):
        try:
            if self.exceptionWindowInput.stringValue() == 'now':
                tmp = self.next_alarm_rule
                tmp2 = self.next_alarm
                self.next_alarm_rule = NowExceptionRule
                self.play_alarm()
                self.next_alarm_rule = tmp
                self.next_alarm = tmp2
            else:
                NSLog('parse user typed exception')
                self.next_alarm_rule = None
                self.set_next_alarm(NSDateToDatetime(NSDateFromString(self.exceptionWindowInput.stringValue())).replace(tzinfo=None), ExceptionRule)
                NSLog('new alarm time %@', self.next_alarm)
        except DidNotUnderstandException:
            alert = NSAlert.alertWithMessageText_defaultButton_alternateButton_otherButton_informativeTextWithFormat_("I'm sorry, I didn't understand that", 'OK', None, None, '')
            alert.runModal()
        sender.window().close()
        
    @IBAction
    def skipAlarm_(self, sender):
        NSLog('skipAlarm:')
        from datetime import timedelta
        next_alarm, rule = get_next_alarm_time_and_rule(self, self.next_alarm+timedelta(seconds=1))
        self.next_alarm = None
        self.next_alarm_rule = None
        self.set_next_alarm(next_alarm, rule)
        self.get_backup_alarm().stop()
    
    @IBAction
    def stopAlarm_(self, sender):
        self.closeAlarmWindow_(self)
        self.get_backup_alarm().stop()
        from appscript import app
        itunes = get_itunes()
        itunes.pause()
    
    @IBAction
    def openWaker_(self, sender):
        self.window.makeKeyAndOrderFront_(sender)
        self.window.orderFrontRegardless()
        self.window.makeFirstResponder_(self.newRuleButton)
        NSApplication.sharedApplication().activateIgnoringOtherApps_(True)
        self.update_tip_window()
        
    @IBAction
    def addRule_(self, sender):
        self.newRuleButton.setEnabled_(False)
        self.new_rule()
    
    @IBAction
    def removeRule_(self, sender):
        self.newRuleButton.setEnabled_(False)
        if sender != None:
            self.managedObjectContext().deleteObject_(sender)
    
    @IBAction
    def setWakeup_(self, sender):
        import datetime
        NSLog('setWakeup: %@',self.next_alarm)
        if self.next_alarm:
            self.bridge.setWakeup_(datetimeToCFAbsoluteTime(self.next_alarm)-5)
            
    @objc.signature('v@:iii')
    @IBAction
    def sendRemoteButtonEvent_pressedDown_remoteControl_(self, buttonEvent, pressedDown, remoteControl):
        from appscript import app, reference
        itunes = get_itunes()
        if pressedDown == 0:
            return
        if buttonEvent == remote_up:
            self.bridge.setVolume_(self.bridge.volume()+0.1)
        elif buttonEvent == remote_down:
            self.bridge.setVolume_(self.bridge.volume()-0.1)
        elif buttonEvent == remote_left:
            itunes.previous_track()
        elif buttonEvent == remote_right:
            itunes.next_track()
        elif buttonEvent == remote_playpause:
            self.snooze()
        
    def managedObjectModel(self):
        if self._managedObjectModel: return self._managedObjectModel
            
        self._managedObjectModel = NSManagedObjectModel.mergedModelFromBundles_(None)
        return self._managedObjectModel

    def persistentStoreCoordinator(self):
        if self._persistentStoreCoordinator: return self._persistentStoreCoordinator
        
        applicationSupportFolder = self.applicationSupportFolder()
        if not os.path.exists(applicationSupportFolder):
            os.mkdir(applicationSupportFolder)
        
        storePath = os.path.join(applicationSupportFolder, "alarms.waker")
        url = NSURL.fileURLWithPath_(storePath)
        self._persistentStoreCoordinator = NSPersistentStoreCoordinator.alloc().initWithManagedObjectModel_(self.managedObjectModel())
        options = {
            'NSMigratePersistentStoresAutomaticallyOption': True,
            'NSInferMappingModelAutomaticallyOption': True,
        }
        
        success, error = self._persistentStoreCoordinator.addPersistentStoreWithType_configuration_URL_options_error_(NSXMLStoreType, None, url, options, None)
        if not success:
            NSApp().presentError_(error)
        
        return self._persistentStoreCoordinator
        
    def managedObjectContext(self):
        if self._managedObjectContext:  return self._managedObjectContext
        
        coordinator = self.persistentStoreCoordinator()
        if coordinator:
            self._managedObjectContext = NSManagedObjectContext.alloc().init()
            self._managedObjectContext.setPersistentStoreCoordinator_(coordinator)
            NSNotificationCenter.defaultCenter().addObserver_selector_name_object_(self, self.objectModelChanged, NSManagedObjectContextObjectsDidChangeNotification, self._managedObjectContext)
        
        return self._managedObjectContext

    def windowWillReturnUndoManager_(self, window):
        return self.managedObjectContext().undoManager()
        
    def objectModelChangedAsync_(self, param):
        if not self.disableModelChangedUpdates:
            NSLog('objectModelChangedAsync:')
            # empty edit rule cache and tell it to reload
            self.previewCalendarView.refresh()
            self.update_tip_window()
            self.set_next_alarm()
            self.newRuleButton.setEnabled_(True)
        
    def objectModelChanged(self):
        self.performSelectorOnMainThread_withObject_waitUntilDone_(self.objectModelChangedAsync_, None, False)
        
    @IBAction
    def saveAction_(self, sender):
        success, error = self.managedObjectContext().save_(None)
        if not success:
            NSApp().presentError_(error)
    
    def applicationShouldTerminate_(self, sender):
        NSUserDefaultsController.sharedUserDefaultsController().save_(self)
    
        if not self._managedObjectContext:
            return NSTerminateNow
        if not self._managedObjectContext.commitEditing():
            return NSTerminateCancel
        
        if self._managedObjectContext.hasChanges():
            success, error = self._managedObjectContext.save_(None)

            if success:
                return NSTerminateNow
            
            if NSApp().presentError_(error):
                return NSTerminateCancel
            else:
                alertReturn = NSRunAlertPanel(None, "Could not save changes while quitting. Quit anyway?" , "Quit anyway", "Cancel", None)
                if alertReturn == NSAlertAlternateReturn:
                    return NSTerminateCancel

        return NSTerminateNow
