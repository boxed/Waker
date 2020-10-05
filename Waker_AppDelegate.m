#import "Waker_AppDelegate.h"
#import "NSDate+NSDate_Humane.h"

static int remote_up = 2;
static int remote_down = 4;
static int remote_left = 64;
static int remote_right = 32;
static int remote_playpause = 16;
static NSString* ExceptionRule = @"Exception";
static NSString* NowExceptionRule = @"User triggered";
// TODO: Replace super user privileged operations with non-deprecated APIs: http://developer.apple.com/library/mac/#samplecode/SMJobBless/Introduction/Intro.html
// -- COOL FEATURES --
// Use any connected microphones to check if the alarm is actually playing in the room. If not, play the backup alarm over the built in speakers.
// RESEARCH: calling phone numbers as alarm. Coupled with a custom ring tone this becomes very useful. Can lead to a bunch of other features like you have to enter a code to say you are awake otherwise it will keep calling. With voice synth and interpretation this can be especially cool.
// RESEARCH: home automation integration

BOOL isDarkMode(void) {
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    return osxMode != nil;
}


@interface NSMutableArray (Shuffling)
- (void)shuffle;
@end

@implementation NSMutableArray (Shuffling)

- (void)shuffle {
    NSUInteger count = [self count];
    for (NSUInteger i = 0; i < count; ++i) {
        // Select a random element between i and end of array to swap with.
        NSInteger nElements = count - i;
        NSInteger n = arc4random_uniform(nElements) + i;
        [self exchangeObjectAtIndex:i withObjectAtIndex:n];
    }
}

@end


@implementation FooCell

- (void)_drawWithFrameInViewCellFrame:(NSRect)cellFrame controlView:(__unused NSView*)controlView {
    NSBezierPath* bp = [NSBezierPath bezierPathWithRect:cellFrame];
    [IntToNSColor([self objectValue]) set];
    [bp fill];
}

@end

static id get_user_default(id key) {
    return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:key];
}

static void set_user_default(NSString* key, NSObject* value) {
    [[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:value forKey:key];
}


@implementation Waker_AppDelegate

- (void)awakeFromNib {
    [self->_rules_controller setSortDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"priority" ascending:YES]]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"system_volume": @0.7, @"first_run": @TRUE, @"snooze_minutes": @10}];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(onSleep:) name:NSWorkspaceWillSleepNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(onWake:) name:NSWorkspaceDidWakeNotification object:nil];
    self->_createNewRuleTipWindow = [[MAAttachedWindow alloc] initWithContentView:self->_createNewRuleTipView attachedToView:self->_createNewRuleButton onSide:3];
}

- (void)applicationDidFinishLaunching:(__unused id)sender {
    // Create and register value transformers
    [NSValueTransformer setValueTransformer:[[DateTransformer alloc] init] forName:@"DateTransformer"];
    
    
    self->_disableModelChangedUpdates = FALSE;
    [self managedObjectContext];
    [self setup_menu];
    [self->_bridge initRights];
    // set up the global timer to call us every 5 seconds
    [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(timer) userInfo:nil repeats:YES];

    @try {
        self->_next_alarm = get_user_default(@"next_alarm");
        self->_next_alarm_rule = get_user_default(@"next_alarm_rule");
    }
    @catch (id) {
        self->_next_alarm = nil;
        self->_next_alarm_rule = nil;
    }
    NSLog(@"previous alarm set: %@", self->_next_alarm);
    if (self->_next_alarm == nil || [[NSDate date] laterThan:self->_next_alarm]) {
        [self setNextAlarm];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(calendarChanged:) name:CalEventsChangedExternallyNotification  object:[CalCalendarStore defaultCalendarStore]];
    if ([get_user_default(@"first_run") boolValue]) {
        [self showFirstRunWindow];
    }

    self->_remote_control = [[AppleRemote alloc] initWithDelegate:self];
    if (self->_remote_control) {
        [self->_remote_control setDelegate:self];
    }
    // debug code
    //self->_show_alarm_window()
    //self->_showFirstRunWindow()
    //self->_openWaker_(self)
    [self setupAirplay];
    
    self->autoSaveTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 repeats:TRUE block:^(NSTimer * _Nonnull __unused timer) {
        if ([self->_managedObjectContext hasChanges]) {
            [self saveAction:self];
        }
    }];
}

- (void)setupAirplay {
    // From: http://joris.kluivers.nl/blog/2012/07/25/per-application-airplay-in-mountain-lion/
    AudioObjectPropertyAddress addr;
    UInt32 propsize;
    
    // target all available audio devices
    addr.mSelector = kAudioHardwarePropertyDevices;
    addr.mScope = kAudioObjectPropertyScopeWildcard;
    addr.mElement = kAudioObjectPropertyElementWildcard;
    
    // get size of available data
    AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &propsize);
    
    int nDevices = propsize / sizeof(AudioDeviceID);
    AudioDeviceID *devids = malloc(propsize);
    
    // get actual device id array data
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &propsize, devids);
    
    // target device transport type property
    addr.mSelector = kAudioDevicePropertyTransportType;
    addr.mScope = kAudioObjectPropertyScopeGlobal;
    addr.mElement = kAudioObjectPropertyElementMaster;
    
    unsigned int transportType = 0;
    propsize = sizeof(transportType);
    for (int i=0; i < nDevices; i++) {
        AudioObjectGetPropertyData(devids[i], &addr, 0, NULL, &propsize, &transportType);
        
        if (kAudioDeviceTransportTypeAirPlay == transportType) {
            // Found AirPlay audio device
            AudioObjectPropertyAddress addr;
            
            // target the data source property
            addr.mSelector = kAudioDevicePropertyDataSource;
            addr.mScope = kAudioDevicePropertyScopeOutput;
            addr.mElement = kAudioObjectPropertyElementMaster;
            
            UInt32 sourceID;
            
            AudioObjectSetPropertyData(devids[i], &addr, 0, NULL, sizeof(UInt32), &sourceID);
            self->_audioDeviceID = devids[i];
            break;
        }
    }
    
    free(devids);
}

- (void)applicationWillBecomeActive:(__unused id)aNotification {
    if (self->_remote_control) {
        [self->_remote_control startListening:self];
    }
}

- (void)applicationWillResignActive:(__unused id)aNotification {
    if (self->_remote_control) {
        [self->_remote_control stopListening:self];
    }
}

- (void)showFirstRunWindow {
    [self->_firstRunWindow center];
    [self->_firstRunWindow makeKeyAndOrderFront:self];
    [self->_firstRunWindow orderFrontRegardless];
}

- (void)calendarChanged:(__unused id)sender {
    NSLog(@"calendarChanged:");
    [self->_previewCalendarView refresh];
    [self setNextAlarm];
}

- (NSMutableArray*)rules {
    NSMutableArray* r = [@[] mutableCopy];
    NSFetchRequest* request = [[NSFetchRequest alloc] init];
    [request setEntity:[self->_managedObjectModel entitiesByName][@"Rule"]];
    [request setSortDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"priority" ascending:YES]]];
    for (NSManagedObject* rule in [self->_managedObjectContext executeFetchRequest:request error:nil]) {
        if (rule) {
            [r addObject:rule];
        }
    }
    return r;
}

- (NSString*)applicationSupportFolder {
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString* basePath = (paths.count > 0) ? paths[0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"Waker"];
}

- (void)setNextAlarmThread:(AlarmTimeAndRule*)params {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"setNextAlarmThread"];

        if (params->next_alarm == nil) {
            params = get_next_alarm_time_and_rule(self, self->_next_alarm);
        }
        if (params != nil && params->next_alarm != nil && ![self->_next_alarm isEqualTo:params->next_alarm]) {
            NSLog(@"next alarm rule: %@", params->rule);
            self->_next_alarm = params->next_alarm;
            self->_next_alarm_rule = params->rule;
            set_user_default(@"next_alarm", self->_next_alarm);
            set_user_default(@"next_alarm_rule", self->_next_alarm_rule);
            [(NSUserDefaultsController*)[NSUserDefaultsController sharedUserDefaultsController] save:self];
            [self setWakeup:self];
        }
    }
}

- (void)setNextAlarm {
    [self setNextAlarm:[AlarmTimeAndRule newWithNextAlarm:nil rule:nil]];
}

- (void)setNextAlarm:(AlarmTimeAndRule*)alarm_and_rule {
    NSLog(@"setNextAlarm %@, %@", alarm_and_rule->next_alarm, alarm_and_rule->rule);
    self->_next_alarm_rule = nil;
    self->_next_alarm = nil;
    if (self->_next_alarm_rule != NowExceptionRule && self->_next_alarm_rule != ExceptionRule) {
        [NSThread detachNewThreadSelector:@selector(setNextAlarmThread:) toTarget:self withObject:alarm_and_rule];
    }
    else {
        NSLog(@"ignored setNextAlarm, %@", self->_next_alarm_rule);
    }
}

- (void)fadeInVolume {
    [NSThread detachNewThreadSelector:@selector(fadeInVolumeThread:) toTarget:self withObject:nil];
}

- (void)fadeInVolumeThread:(__unused id)params {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"fadeInVolumeThread"];
        NSLog(@"fadeInVolume");
        float volume = 0;
        float target = [get_user_default(@"system_volume") floatValue];
        float step = target/1000.0;
        while (TRUE) {
            if (![self->_alarmWindow isVisible]) {
                break;
            }
            [NSThread sleepForTimeInterval:0.1f];
            [self->_bridge setVolume:volume];
            volume += step;
            if (volume >= target) {
                break;
            }
        }
    }
}

- (void)fadeOutVolume {
    [NSThread detachNewThreadSelector:@selector(fadeOutVolumeThread:) toTarget:self withObject:nil];
}

- (void)fadeOutVolumeThreadParams:(__unused id)params {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"fadeOutVolumeThread"];
        NSLog(@"fadeOutVolume");
        float volume = [self->_bridge volume];
        float step = 0.005;
        float target = 0;
        while (TRUE) {
            if (![self->_alarmWindow isVisible]) {
                break;
            }
            sleep(0.1);
            [self->_bridge setVolume:volume];
            volume -= step;
            if ((volume <= target)) {
                break;
            }
        }
    }
}

- (void)timer {
    if (self->_next_alarm) {
        if ([[NSDate date] laterThan:self->_next_alarm]) {
            if ([[NSDate date] laterThan:[self->_next_alarm dateWithOffsetDays:0 hours:0 minutes:30 seconds:0]]) {
                NSLog(@"missed the alarm slot by more than 30 minutes, skipping");
                [self setNextAlarm];
                return;
            }
            [self play_alarm];
        }
        if ([[[NSDate date] dateWithOffsetDays:0 hours:0 minutes:-5 seconds:0] laterThan:self->_next_alarm]) {
            [self setNextAlarm];
        }
    }
    [self update_menu_preview];
    [self->_alarmWindowTime setStringValue:[[NSDate date] descriptionWithCalendarFormat:@"%H:%M" timeZone:nil locale:nil]];
    /*if ((self->_large_type_window != nil)) {
        NSLog(@"cancel large type");
        [self->_large_type_window close];
        self->_large_type_window = nil;
    }*/
}

- (void)play_alarm {
    if (_music_files_player) {
        return;
    }
    [self->_bridge setVolume:0];
    [self show_alarm_window];
    
    _music_files = [@[] mutableCopy];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSURL *directoryURL = [NSURL fileURLWithPath:[@"~/Music/Waker/" stringByStandardizingPath]];
    NSError* err = nil;
    if ([directoryURL checkResourceIsReachableAndReturnError:&err] == NO) {
        directoryURL = [NSURL fileURLWithPath:[@"~/Music/" stringByStandardizingPath]];
    }
    
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:@[NSURLIsRegularFileKey]
                                         options:0
                                         errorHandler:^(__unused NSURL *url, __unused NSError *error) {
                                             // Handle the error.
                                             // Return YES if the enumeration should continue after the error.
                                             return YES;
                                         }];
    for (NSURL *url in enumerator) {
        NSString* ext = [url pathExtension];
        if ([ext isEqualToString:@"mp3"] || [ext isEqualToString:@"m4a"]) {
            [_music_files addObject:url];
        }
    }
    _music_files_player_index = 0;
    if (_music_files.count) {
        [_music_files shuffle];
    }
    else {
        NSLog(@"backup alarm!");
        NSURL* backupAlarm = [[NSBundle mainBundle] URLForResource:@"backup" withExtension:@"mp3"];
        [_music_files addObject:backupAlarm];
    }
    [self nextSong];
    
    [self fadeInVolume];
    [self setNextAlarm];
}

// NSSoundDelegate
- (void)sound:(__unused NSSound *)sound didFinishPlaying:(__unused BOOL)finishedPlaying {
    if (_music_files.count) {
        [self nextSong];
    }
}

- (void)nextSong {
    _music_files_player_index++;
    
    if (_music_files_player_index >= _music_files.count) {
        _music_files_player_index = 0;
    }
    
    _music_files_player = [[NSSound alloc] initWithContentsOfURL:_music_files[_music_files_player_index] byReference:YES];
    /*if (_audioDeviceID) {
        
        UInt32 size = sizeof(CFStringRef);
        CFStringRef str = NULL;
        AudioDeviceGetProperty(_audioDeviceID,  0, 0, kAudioDevicePropertyDeviceUID, &size, &str);
        
        [_music_files_player setPlaybackDeviceIdentifier:(__bridge NSString*)str];
    }*/
    _music_files_player.delegate = self;
    [_music_files_player play];
}

- (void)snooze {
    float minutes = [get_user_default(@"snooze_minutes") floatValue];
    [self fadeOutVolume];
    [_music_files_player pause];
    [NSTimer scheduledTimerWithTimeInterval:(int)(minutes * 60) target:self selector:@selector(unSnooze) userInfo:nil repeats:NO];
}

- (void)unSnooze {
    [_music_files_player play];
}

static NSString* events_as_string(NSDate* calendar) {
    NSArray *events = events_of_day(calendar.year, calendar.month, calendar.day);
    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:events.count];
    [events enumerateObjectsUsingBlock:^(id obj, NSUInteger __unused idx, BOOL __unused *stop) {
        [titles addObject:[obj title]];
    }];
    return [titles componentsJoinedByString:@"\n"];
}

- (void)show_alarm_window {
    [self->_alarmWindow setBackgroundColor:[NSColor blackColor]];
    if ([self->_alarmWindow isVisible]) {
        NSLog(@"Warning! alarm already active but tried to start it anyway");
    }
    [self->_alarmWindow orderFrontRegardless];
    [self->_alarmWindow toggleFullScreen:self];
    // TODO: update the day titles and texts
    NSDate* calendar = [NSDate date];

    NSArray* weekdays = @[@"Monday", @"Tuesday", @"Wednesday", @"Thursday", @"Friday", @"Saturday", @"Sunday"];
    
    [self->_alarmWindowDay1Text setStringValue:events_as_string(calendar)];
    calendar = [calendar dateWithOffsetDays:1 hours:0 minutes:0 seconds:0];
    [self->_alarmWindowDay2Text setStringValue:events_as_string(calendar)];
    calendar = [calendar dateWithOffsetDays:1 hours:0 minutes:0 seconds:0];
    [self->_alarmWindowDay3Text setStringValue:events_as_string(calendar)];
    [self->_alarmWindowDay3Title setStringValue:weekdays[[calendar weekday]]];
    calendar = [calendar dateWithOffsetDays:1 hours:0 minutes:0 seconds:0];
    [self->_alarmWindowDay4Text setStringValue:events_as_string(calendar)];
    [self->_alarmWindowDay4Title setStringValue:weekdays[[calendar weekday]]];
    calendar = [calendar dateWithOffsetDays:1 hours:0 minutes:0 seconds:0];
    [self->_alarmWindowDay5Text setStringValue:events_as_string(calendar)];
    [self->_alarmWindowDay5Title setStringValue:weekdays[[calendar weekday]]];
    calendar = [calendar dateWithOffsetDays:1 hours:0 minutes:0 seconds:0];
    [self->_alarmWindowDay6Text setStringValue:events_as_string(calendar)];
    [self->_alarmWindowDay6Title setStringValue:weekdays[[calendar weekday]]];
    calendar = [calendar dateWithOffsetDays:1 hours:0 minutes:0 seconds:0];
    [self->_alarmWindowDay7Text setStringValue:events_as_string(calendar)];
    [self->_alarmWindowDay7Title setStringValue:weekdays[[calendar weekday]]];
    [self->_alarmWindowMatchedRule setStringValue:self->_next_alarm_rule];
    [self->_alarmWindowStopAlarmButton.cell setBackgroundColor:[NSColor colorWithDeviceWhite:0.2 alpha:1.0]];
    //TODO: [self->_alarmWindowStopAlarmButton.cell setTextColor:NSColor.whiteColor];
}

- (IBAction)closeAlarmWindow:(__unused id)sender {
    [self->_alarmWindow close];
    [self->_alarmWindow orderOut:self];
}

- (void)setup_menu {
    NSStatusBar* statusBar = [NSStatusBar systemStatusBar];
    self->_statusItem = [statusBar statusItemWithLength:37];
    [self->_statusItem setMenu:self->_statusBarMenu];
    [self->_statusItem setHighlightMode:TRUE];

    if (isDarkMode) {
        [self->_statusItem setImage:[NSImage imageNamed:@"menu_item_inverted.png"]];
    }
    else {
        // light mode
        [self->_statusItem setImage:[NSImage imageNamed:@"menu_item.png"]];
    }
}

- (void)update_menu_preview {
    NSString* next_alarm_description;
    if (self->_next_alarm) {
        next_alarm_description = [self->_next_alarm relativeDescription];
        // TODO: next_alarm_description = relative_date_formatting(self->_next_alarm);
    }
    else {
        next_alarm_description = @"No alarm set";
    }
    [self->_statusBarMenuPreviewItem setTitle:next_alarm_description];
}

- (void)onWake:(__unused NSNotification*)notification {
    self->_just_woke = TRUE;
    NSLog(@"onWake");
}

- (void)onSleep:(__unused NSNotification*)notification {
    if (self->_next_alarm != nil) {
        // display next alarm time and delay some time to allow the user to see the message
        self->_just_woke = FALSE;
        //TODO: NSWindow* foo = [self->_bridge QSShowLargeType:@"Next alarm: %s" % str(relative_date_formatting(self->_next_alarm))];
        /*NSWindow* foo = [self->_bridge QSShowLargeType:[NSString stringWithFormat:@"Next alarm: %@", self->_next_alarm]];
        NSLog(@"delaying sleep...");
        for (int i = 0; i != 5; i++) {
            if (self->_just_woke || [self->_bridge lidClosed]) {
                NSLog(@"just woke!");
                break;
            }
            [[NSRunLoop currentRunLoop] runUntilDate:[[NSDate date] dateWithOffsetDays:0 hours:0 minutes:0 seconds:1]];
        }
        self->_large_type_window = foo;
        NSLog(@"done with onSleep");*/
    }
}

- (NSManagedObject*)new_rule {
    NSManagedObject* __block obj = nil;
    [self->_managedObjectContext performBlockAndWait:^{
        [[self->_managedObjectContext undoManager] beginUndoGrouping];
        [[self->_managedObjectContext undoManager] setActionName:@"new rule"];
        obj = [NSEntityDescription insertNewObjectForEntityForName:@"Rule" inManagedObjectContext:self->_managedObjectContext];
        [obj setName:@"unnamed"];
        [[self->_managedObjectContext undoManager] endUndoGrouping];
    }];
    return obj;
}

- (void)update_tip_window {
    if ([[self->_rules_controller arrangedObjects] count] == 0 && [self->_window isVisible]) {
        [self->_createNewRuleTipWindow show:self];
    }
    else {
        [self->_createNewRuleTipWindow hide:self];
    }
}

- (IBAction)firstRunCreateDefaultRules:(__unused id)sender {
    self->_disableModelChangedUpdates = TRUE;
    [self->_managedObjectContext performBlock:^{
        [[self->_managedObjectContext undoManager] beginUndoGrouping];
        [[self->_managedObjectContext undoManager] setActionName:@"default rules"];
        NSManagedObject* abroad = [self new_rule];
        [abroad setName:@"Abroad"];
        [abroad setPredicate:@"title BEGINSWITH[cd] \"abroad\""];
        [abroad setPriority:@1];
        [abroad setColor:@1507165];
        NSManagedObject* vacation = [self new_rule];
        [vacation setName:@"Vacation"];
        [vacation setPredicate:@"title CONTAINS[cd] \"vacation\""];
        [vacation setPriority:@2];
        [vacation setTime:@"11:00"];
        [vacation setColor:@1507165];
        NSManagedObject* workday = [self new_rule];
        [workday setName:@"Workday"];
        [workday setPredicate:@"day !=[c] \"Sunday\" AND day !=[c] \"Saturday\""];
        [workday setPriority:@3];
        [workday setTime:@"07:00"];
        [workday setColor:@10201855];
        NSManagedObject* weekend = [self new_rule];
        [weekend setName:@"Weekend"];
        [weekend setPredicate:@"day ==[c] \"Saturday\" OR day ==[c] \"Sunday\""];
        [weekend setPriority:@4];
        [weekend setTime:@"10:00"];
        [weekend setColor:@16735087];
        [[self->_managedObjectContext undoManager] endUndoGrouping];
        set_user_default(@"first_run", @FALSE);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_firstRunWindow close];
        });
        self->_disableModelChangedUpdates = FALSE;
        [self openWaker:self];
        [self objectModelChanged];
    }];

}

- (IBAction)firstRunNoDefaultRules:(__unused id)sender {
    set_user_default(@"first_run", @FALSE);
    [self->_firstRunWindow close];
    [self openWaker:self];
}

- (IBAction)showExceptionWindow:(id)sender {
    [self->_exceptionWindow makeKeyAndOrderFront:sender];
    [self->_exceptionWindow orderFrontRegardless];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:TRUE];
    [[self->_exceptionWindow fieldEditor:YES forObject:self->_exceptionWindowInput] setSelectedRange:NSMakeRange(12, 100)];
    [self->_exceptionWindowOutput setStringValue:@""];
}

- (IBAction)controlTextDidChange:(id)notification {
    if (([notification object] == self->_exceptionWindowInput)) {
        [self->_exceptionWindowOutput setStringValue:[self parseExceptionInput]];
    }
}

- (IBAction)showAboutWindow:(id)sender {
    [self->_aboutWindow center];
    [self->_aboutWindow makeKeyAndOrderFront:sender];
    [self->_aboutWindow orderFrontRegardless];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:TRUE];
}

- (NSString*)parseExceptionInput {
    @try {
        if ([[self->_exceptionWindowInput stringValue] isEqualToString:@"now"]) {
            return @"now";
        }
        else {
            NSDate* date = NSDateFromString([self->_exceptionWindowInput stringValue]);
            return [NSString stringWithFormat:@"%@\n%@", [date description], [date relativeDescription]];
        }
    }
    @catch (DidNotUnderstandException*, KeyError*) {
        return @"I'm sorry, I didn't understand that";
    }
}

- (IBAction)setException:(id)sender {
    @try {
        if ([[self->_exceptionWindowInput stringValue] isEqualToString:@"now"]) {
            NSString* tmp = self->_next_alarm_rule;
            NSDate* tmp2 = self->_next_alarm;
            self->_next_alarm_rule = NowExceptionRule;
            [self play_alarm];
            self->_next_alarm_rule = tmp;
            self->_next_alarm = tmp2;
        }
        else {
            self->_next_alarm_rule = nil;
            [self setNextAlarm:[AlarmTimeAndRule newWithNextAlarm:NSDateFromString([self->_exceptionWindowInput stringValue]) rule:ExceptionRule]];
            NSLog(@"new alarm time %@", self->_next_alarm);
        }
    }
    @catch (DidNotUnderstandException* ) {
        NSAlert* alert = [NSAlert alertWithMessageText:@"I'm sorry, I didn't understand that" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
        [alert runModal];
    }
    [[sender window] close];
}

- (IBAction)skipAlarm:(__unused id)sender {
    NSLog(@"skipAlarm:");
    AlarmTimeAndRule* params = get_next_alarm_time_and_rule(self, [self->_next_alarm dateWithOffsetDays:0 hours:0 minutes:0 seconds:1]);

    self->_next_alarm = nil;
    self->_next_alarm_rule = nil;
    [self setNextAlarm:params];
    [self->_backup_alarm stop];
}

- (IBAction)stopAlarm:(__unused id)sender {
    [self closeAlarmWindow:self];
    [_backup_alarm stop];
    _music_files = nil;
    [_music_files_player stop];
    _music_files_player = nil;
}

- (IBAction)openWaker:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_window makeKeyAndOrderFront:sender];
        [self->_window orderFrontRegardless];
        [self->_window makeFirstResponder:self->_createNewRuleButton];
        [[NSApplication sharedApplication] activateIgnoringOtherApps:TRUE];
        [self update_tip_window];
    });
}

- (IBAction)addRule:(__unused id)sender {
    [self->_createNewRuleButton setEnabled:FALSE];
    [self new_rule];
}

- (IBAction)removeRule:(id)sender {
    [self->_createNewRuleButton setEnabled:FALSE];
    if (sender != nil) {
        [self->_managedObjectContext deleteObject:sender];
    }
}

- (IBAction)setWakeup:(__unused id)sender {
    NSLog(@"setWakeup: %@", self->_next_alarm);
    if (self->_next_alarm) {
        [self->_bridge setWakeup:CFDateGetAbsoluteTime((CFDateRef)self->_next_alarm) - 5];
    }
}


- (IBAction)sendRemoteButtonEvent:(RemoteControlEventIdentifier)buttonEvent pressedDown:(BOOL)pressedDown remoteControl:(__unused RemoteControl*)remoteControl {
    if (pressedDown == 0) {
        return;
    }
    if (buttonEvent == remote_up) {
        [self->_bridge setVolume:[self->_bridge volume] + 0.1];
    }
    else if (buttonEvent == remote_down) {
        [self->_bridge setVolume:[self->_bridge volume] - 0.1];
    }
    else if (buttonEvent == remote_left) {
//TODO:        [itunes previous_track];
    }
    else if (buttonEvent == remote_right) {
//TODO:        [itunes next_track];
    }
    else if (buttonEvent == remote_playpause) {
        [self snooze];
    }
}

- (NSManagedObjectModel*)managedObjectModel {
    if (self->_managedObjectModel) {
        return self->_managedObjectModel;
    }
    self->_managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    return self->_managedObjectModel;
}

- (NSPersistentStoreCoordinator*)persistentStoreCoordinator {
    if (self->_persistentStoreCoordinator) {
        return self->_persistentStoreCoordinator;
    }
    NSString* folder = [self applicationSupportFolder];
    if (![[NSFileManager defaultManager] fileExistsAtPath:folder]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString* storePath = [folder stringByAppendingPathComponent:@"alarms.waker"];
    NSURL* url = [NSURL fileURLWithPath:storePath];
    self->_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSDictionary* options = @{@"NSMigratePersistentStoresAutomaticallyOption": @TRUE, @"NSInferMappingModelAutomaticallyOption": @TRUE};
    NSError* error = nil;
    if (![self->_persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:options error:&error]) {
        [NSApp presentError:error];
    }
    return self->_persistentStoreCoordinator;
}

- (NSManagedObjectContext*)managedObjectContext {
    if (self->_managedObjectContext) {
        return self->_managedObjectContext;
    }
    NSPersistentStoreCoordinator* coordinator = [self persistentStoreCoordinator];
    if (coordinator) {
        self->_managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [self->_managedObjectContext setPersistentStoreCoordinator:coordinator];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(objectModelChanged)
                                                     name:NSManagedObjectContextObjectsDidChangeNotification
                                                   object:self->_managedObjectContext];
    }
    return self->_managedObjectContext;
}

- (NSUndoManager*)windowWillReturnUndoManager:(__unused id)window {
    return [self->_managedObjectContext undoManager];
}

- (void)objectModelChangedAsync:(__unused id)param {
    // TODO: this seems to fire all the time... disable for now
    if (!self->_disableModelChangedUpdates) {
        NSLog(@"objectModelChangedAsync:");
        // empty edit rule cache and tell it to reload
        [self->_previewCalendarView refresh];
        [self update_tip_window];
        [self setNextAlarm];
        [self->_createNewRuleButton setEnabled:TRUE];
    }
}

- (void)objectModelChanged {
    [self performSelectorOnMainThread:@selector(objectModelChangedAsync:) withObject:nil waitUntilDone:FALSE];
}

- (IBAction)saveAction:(__unused id)sender {
    NSError* error = nil;
    if (![self->_managedObjectContext save:&error]) {
        [NSApp presentError:error];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(__unused id)sender {
    [(NSUserDefaultsController*)[NSUserDefaultsController sharedUserDefaultsController] save:self];
    if (!self->_managedObjectContext) {
        return NSTerminateNow;
    }
    if (![self->_managedObjectContext commitEditing]) {
        return NSTerminateCancel;
    }
    if ([self->_managedObjectContext hasChanges]) {
        NSError* error = nil;
        if ([self->_managedObjectContext save:&error]) {
            return NSTerminateNow;
        }
        if ([NSApp presentError:error]) {
            return NSTerminateCancel;
        }
        else {
            NSInteger alertReturn = NSRunAlertPanel(nil, @"Could not save changes while quitting. Quit anyway?", @"Quit anyway", @"Cancel", nil);
            if (alertReturn == NSAlertAlternateReturn) {
                return NSTerminateCancel;
            }
        }
    }
    return NSTerminateNow;
}

@end
