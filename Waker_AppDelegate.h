#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "RemoteControl.h"
#import "AppleRemote.h"
#import "MAAttachedWindow.h"
#import "ObjcBridge.h"
#import "CalendarView.h"
#import <CalendarStore/CalendarStore.h>
#import "transformers.h"
#import "waker.h"

@interface Waker_AppDelegate : NSObject<Settings, NSSoundDelegate> {
    NSSound* _backup_alarm;
    NSManagedObjectContext* _managedObjectContext;
    NSManagedObjectModel* _managedObjectModel;
    NSPersistentStoreCoordinator* _persistentStoreCoordinator;
    
    RemoteControl* _remote_control;
    BOOL _disableModelChangedUpdates;
    NSDate* _next_alarm;
    NSString* _next_alarm_rule;
    id _statusItem;
    id _timer;
    NSArray * _weekdays;
    BOOL _just_woke;
    NSWindow* _large_type_window;
    NSMutableArray* _music_files;
    NSSound* _music_files_player;
    int _music_files_player_index;
}

@property IBOutlet NSWindow* aboutWindow;
@property IBOutlet NSWindow* alarmWindow;
@property IBOutlet NSTextField* alarmWindowDay1Text;
@property IBOutlet NSTextField* alarmWindowDay1Title;
@property IBOutlet NSTextField* alarmWindowDay2Text;
@property IBOutlet NSTextField* alarmWindowDay2Title;
@property IBOutlet NSTextField* alarmWindowDay3Text;
@property IBOutlet NSTextField* alarmWindowDay3Title;
@property IBOutlet NSTextField* alarmWindowDay4Text;
@property IBOutlet NSTextField* alarmWindowDay4Title;
@property IBOutlet NSTextField* alarmWindowDay5Text;
@property IBOutlet NSTextField* alarmWindowDay5Title;
@property IBOutlet NSTextField* alarmWindowDay6Text;
@property IBOutlet NSTextField* alarmWindowDay6Title;
@property IBOutlet NSTextField* alarmWindowDay7Text;
@property IBOutlet NSTextField* alarmWindowDay7Title;
@property IBOutlet id alarmWindowMatchedRule;
@property IBOutlet NSButton* alarmWindowStopAlarmButton;
@property IBOutlet id alarmWindowTime;
@property IBOutlet ObjcBridge* bridge;
@property IBOutlet NSWindow* exceptionWindow;
@property IBOutlet id exceptionWindowInput;
@property IBOutlet NSTextField* exceptionWindowOutput;
@property IBOutlet NSWindow* firstRunWindow;
@property IBOutlet id createNewRuleButton;
@property IBOutlet id createNewRuleTipView;
@property IBOutlet MAAttachedWindow* createNewRuleTipWindow;
@property IBOutlet id predicateEditor;
@property IBOutlet CalendarView* previewCalendarView;
@property IBOutlet id rules_controller;
@property IBOutlet id statusBarMenu;
@property IBOutlet id statusBarMenuPreviewItem;
@property IBOutlet id window;

@end


@interface FooCell : NSCell {
}
@end


@interface NSManagedObject (RuleAccessors)

@property (nonatomic) NSNumber* color;
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* predicate;
@property (nonatomic) NSNumber* priority;
@property (nonatomic) NSString* time;

@end


