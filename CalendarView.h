#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface CalendarView : NSView {
    NSMutableDictionary* cache;
    id endLoading_;
    id loadDataThread_;
    BOOL loading;
    id loadingThread;
    IBOutlet id progress;
    IBOutlet id title;
    int _month;
    int _year;
}

- (void)refresh;
@end
