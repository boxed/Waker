#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioServices.h>

@interface ObjcBridge : NSObject {
}

- (void)initRights;
- (bool)setWakeup:(CFAbsoluteTime)inAbsoluteTime;
- (void)sleepSystem;
- (bool)destroyRights;
- (float)volume;
- (void)setVolume:(Float32)newVolume;
- (NSWindow*)QSShowLargeType:(NSString*)inString;
- (AudioDeviceID)defaultOutputDeviceID;
- (long)idleTimeSeconds;
- (int32_t)captureDisplayAndGetShieldingLevel;
- (bool)releaseDisplay;
- (void)testAbsoluteTimeConversion:(double)t;
@end