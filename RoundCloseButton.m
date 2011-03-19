#import "RoundCloseButton.h"

@implementation RoundCloseButton

- (void)drawRect:(NSRect)rect
{
	NSImage* image = [NSImage imageNamed:@"hud_titlebar-close-dark"];
	NSRect r = {{0, rect.origin.y}, {14, 14}};
	[image drawAtPoint:rect.origin fromRect:r operation:NSCompositeSourceOver fraction:1];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

@end
