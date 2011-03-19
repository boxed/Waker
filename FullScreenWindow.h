#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import "ObjcBridge.h"

@interface FullScreenWindow : NSWindow {
    IBOutlet ObjcBridge* bridge;
    IBOutlet NSButton* closeButton;
    int hideCount;
}

- (void)goFullscreen;
- (void)exitFullscreen:(id)sender;

@end
