//
//  QSGlobalSelectionProvider.m
//  Quicksilver
//
//  Created by Alcor on 1/21/05.

//

#import "QSGlobalSelectionProvider.h"

#define VERBOSE 1
#define QSLog NSLog

@implementation QSGlobalSelectionProvider

NSTimeInterval failDate=0;

- (void)registerProvider
{
    //[NSApp setServicesProvider:self];
    //NSLog(@"Registered service provider");
}

- (void)getSelection:(NSPasteboard *)pboard
            userData:(NSString *)userData
               error:(__unused NSString **)error
{
    NSLog(@"Get Selection: %@ %d",userData,[userData characterAtIndex:0]);
    resultPboard=pboard;
}

//- (void)performService:(NSPasteboard *)pboard
//              userData:(NSString *)userData
//                 error:(NSString **)error
//{
//    NSLog(@"xPerform Service: %@ %d",userData,[userData characterAtIndex:0]);
//}

- (NSPasteboard *)getSelectionFromFrontApp
{
    
    //QSLog(@"GET SEL");
    //id oldServicesProvider=[NSApp servicesProvider];
    //[self invokeService];
    [NSThread detachNewThreadSelector:@selector(invokeService)
                             toTarget:self withObject:nil];
    
    //      return nil;
    NSRunLoop *loop=[NSRunLoop currentRunLoop];
    NSDate *date=[NSDate date];
    while(!resultPboard && [date timeIntervalSinceNow]>-2){
        [loop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        //      QSLog(@"loop");
    }
    //      QSLog(@"got %@",resultPboard);
    //[NSApp setServicesProvider:oldServicesProvider];
    id result=resultPboard;
    resultPboard=nil;
    return result;
}


- (void)dealloc
{
    QSLog(@"release");
}

- (void)invokeService
{
    @autoreleasepool {
        pid_t pid=[[[[NSWorkspace sharedWorkspace]activeApplication]objectForKey:@"NSApplicationProcessIdentifier"]intValue];
        AXUIElementRef app=AXUIElementCreateApplication (pid);
        
        //      NDProcess *proc=[NDProcess frontProcess];
        
        //BOOL carbon=[proc isCarbon];
        
        AXUIElementPostKeyboardEvent (app,(CGCharCode)0, (CGKeyCode)55, true ); //Command
        //      if (carbon) AXUIElementPostKeyboardEvent (app,(CGCharCode)0, (CGKeyCode)56, true ); //Shift
        AXUIElementPostKeyboardEvent (app,(CGCharCode)0, (CGKeyCode)53, true ); //Escape
        AXUIElementPostKeyboardEvent (app,(CGCharCode)0, (CGKeyCode)53, false ); //Escape
        //      if (carbon) AXUIElementPostKeyboardEvent (app,(CGCharCode)0, (CGKeyCode)56, false ); //Shift
        AXUIElementPostKeyboardEvent (app,(CGCharCode)0, (CGKeyCode)55, true ); //Command
    }
}

+(id)currentSelection{
    //NSDictionary *appDictionary=[[NSWorkspace sharedWorkspace]activeApplication];
    //NSString *identifier=[appDictionary objectForKey:@"NSApplicationBundleIdentifier"];
    
//    id provider = [QSReg instanceForPointID:@"QSProxies" withID:identifier];
//    if (provider) {
//        return [provider resolveProxyObject:nil];
//    }else{
        
        NSPasteboard *pb=nil;
        
//        if ([NSDate timeIntervalSinceReferenceDate]-failDate > 3.0)
//            pb=[self getSelectionFromFrontApp];
//        
//        if (!pb){
//            failDate=[NSDate timeIntervalSinceReferenceDate];
//            return nil;
//        }
        return pb;
//    }
//    return [QSObject objectWithString:@"No Selection"]; //[QSObject nullObject];
}
-(id)resolveProxyObject:(id)proxy{
    id object=[QSGlobalSelectionProvider currentSelection];
    //QSLog(@"object %@",object);
    return object;
}
-(BOOL)bypassValidation{
    NSDictionary *appDictionary=[[NSWorkspace sharedWorkspace]activeApplication];
    NSString *identifier=[appDictionary objectForKey:@"NSApplicationBundleIdentifier"];
    if ([identifier isEqualToString:@"com.blacktree.Quicksilver"])
        return YES;
    else
        return NO;
}
//-(NSArray *)typesForProxyObject:(id)proxy{
//    NSDictionary *appDictionary=[[NSWorkspace sharedWorkspace]activeApplication];
//    NSString *identifier=[appDictionary objectForKey:@"NSApplicationBundleIdentifier"];
//    NSDictionary *info=[[QSReg elementForPointID:@"QSProxies" withID:identifier] plistContent];
//    NSArray *array=[info objectForKey:kQSProxyTypes];
//    if (!info)return [NSArray arrayWithObjects:NSStringPboardType,NSFilenamesPboardType,nil];
//    if (array)return array;
//    
//    id provider=[QSReg getClassInstance:[info objectForKey:kQSProxyProviderClass]];
//    return [provider typesForProxyObject:self];
//}
@end
