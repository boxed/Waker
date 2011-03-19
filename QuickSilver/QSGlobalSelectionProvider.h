//
//  QSGlobalSelectionProvider.h
//  Quicksilver
//
//  Created by Alcor on 1/21/05.

//

#import <Cocoa/Cocoa.h>

@interface QSGlobalSelectionProvider : NSObject {
    NSTimeInterval failDate;
    NSPasteboard *resultPboard;
}
- (void)invokeService;
- (NSPasteboard *)getSelectionFromFrontApp;
- (void)registerProvider;
- (void)getSelection:(NSPasteboard *)pboard
            userData:(NSString *)userData
               error:(NSString **)error;
+(id)currentSelection;
@end