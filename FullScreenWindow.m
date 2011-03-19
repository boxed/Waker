#import "FullScreenWindow.h"

@implementation FullScreenWindow

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)hideCloseButton:(id)sender
{
    if (![closeButton isHidden] && [self alphaValue] == 1.0)
    {
        if (hideCount == 4)
        {
            [[closeButton animator] setAlphaValue:0.0];
            CGDisplayHideCursor(kCGDirectMainDisplay);
        }
        else if (hideCount < 4)
        {
            hideCount++;
        }
    }
}

- (void)goFullscreen
{
    NSLog(@"goFullscreen");
    [self setAlphaValue:1.0];
    [self setStyleMask:NSBorderlessWindowMask];
    [self setFrame:[[NSScreen mainScreen] frame] display:NO];
    [self setLevel:[bridge captureDisplayAndGetShieldingLevel]];
    [bridge releaseDisplay];
    [self makeKeyAndOrderFront:self];
    [self orderFrontRegardless];
    [self setAcceptsMouseMovedEvents:YES];
    hideCount = 4; // show the button a little while but fade it away almost directly
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(hideCloseButton:) userInfo:nil repeats:YES];
}

- (void)exitFullscreen:(id)sender
{
    NSLog(@"exitFullscreen");
    [[self animator] setAlphaValue:0.0];
    [bridge releaseDisplay];
    CGDisplayShowCursor(kCGDirectMainDisplay);
    [self resignKeyWindow];
}

- (BOOL)isVisible
{
    if ([self alphaValue] == 0.0)
        return NO;
    else
        return [super isVisible];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    [[closeButton animator] setAlphaValue:1.0];
    hideCount = 0;
    CGDisplayShowCursor(kCGDirectMainDisplay);
}

@end
