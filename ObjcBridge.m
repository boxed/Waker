#include "ObjcBridge.h"
#include "BetterAuthorizationSampleLib.h"
#include "SampleCommon.h"
#import "QuickSilver/QSLargeTypeDisplay.h"
#import "QuickSilver/QSGlobalSelectionProvider.h"
#include <IOKit/IOKitLib.h>

/////////////////////////////////////////////////////////////////
#pragma mark ***** Globals

static AuthorizationRef gAuth = NULL;

/////////////////////////////////////////////////////////////////
#pragma mark ***** Objective-C Wrapper

// Our trivial application object, SampleApp, is instantiated by our nib.  It 
// has four actions, three for the buttons and one for the Destroy Rights menu item. 
// It has a two outlets, one pointing to the text view where we log our results 
// and the other referencing the "Force failure" checkbox.

@implementation ObjcBridge

- (void)initRights
{
	OSStatus    junk;
    
    // Create the AuthorizationRef that we'll use through this application.  We ignore 
    // any error from this.  A failure from AuthorizationCreate is very unusual, and if it 
    // happens there's no way to recover; Authorization Services just won't work.
	
    junk = AuthorizationCreate(NULL, NULL, kAuthorizationFlagDefaults, &gAuth);
    assert(junk == noErr);
    assert( (junk == noErr) == (gAuth != NULL) );
	
	// For each of our commands, check to see if a right specification exists and, if not,
    // create it.
    //
    // The last parameter is the name of a ".strings" file that contains the localised prompts 
    // for any custom rights that we use.
    
	BASSetDefaultRules(
					   gAuth, 
					   kWakerCommandSet, 
					   CFBundleGetIdentifier(CFBundleGetMainBundle()), 
					   CFSTR("WakerPrompts")
					   );
}

- (bool)setWakeup:(CFAbsoluteTime)inAbsoluteTime
{
    OSStatus        err = !noErr;
    @synchronized(self)
    {
        NSString *      bundleID;
        NSDictionary *  request;
        CFDictionaryRef response;
        BASFailCode     failCode;

        response = NULL;
        
        /*printf("%f\n%f\n%f\n", 
               CFAbsoluteTimeGetCurrent()+60, 
               inAbsoluteTime, 
               CFAbsoluteTimeGetCurrent()+60-inAbsoluteTime);
        */
        CFDateRef targetDate = CFDateCreate(NULL, inAbsoluteTime); // in one mins
        NSDate* foo = (NSDate*)targetDate;
        NSLog(@"Wake computer at: %@", [foo description]);
        
        // Create our request.  Note that NSDictionary is toll-free bridged to CFDictionary, so 
        // we can use an NSDictionary as our request.  Also, if the "Force failure" checkbox is 
        // checked, we use the wrong command ID to deliberately cause an "unknown command" error 
        // so that we can test that code path.
        
        request = [NSDictionary dictionaryWithObjectsAndKeys:
                    @kWakerSetWakeupEventCommand, @kBASCommandKey,
                    targetDate,	@kWakerSetWakeupEventKeyDate,     
                    nil];

        assert(request != NULL);
        
        bundleID = [[NSBundle mainBundle] bundleIdentifier];
        assert(bundleID != NULL);
        
        // Execute it.
        
        err = BASExecuteRequestInHelperTool(
            gAuth, 
            kWakerCommandSet, 
            (CFStringRef) bundleID, 
            (CFDictionaryRef) request, 
            &response
        );
        
        // If it failed, try to recover.
        
        if ( (err != noErr) && (err != userCanceledErr) ) {
            int alertResult;
            
            failCode = BASDiagnoseFailure(gAuth, (CFStringRef) bundleID);
            
            // At this point we tell the user that something has gone wrong and that we need 
            // to authorize in order to fix it.  Ideally we'd use failCode to describe the type of 
            // error to the user.
            
            alertResult = NSRunAlertPanel(@"Needs Install", @"Waker needs to install the wake up tool", nil, nil, nil);
            
            if ( alertResult == NSAlertDefaultReturn ) {
                // Try to fix things.
                
                err = BASFixFailure(gAuth, (CFStringRef) bundleID, CFSTR("InstallTool"), CFSTR("HelperTool"), failCode);
                if (err != noErr)
                {
                    NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"Failed to fix failure: %ld.\n", (long) err], nil, nil, nil);
                }
                
                // If the fix went OK, retry the request.
                
                if (err == noErr) {
                    err = BASExecuteRequestInHelperTool(
                                                        gAuth, 
                                                        kWakerCommandSet, 
                                                        (CFStringRef) bundleID, 
                                                        (CFDictionaryRef) request, 
                                                        &response
                                                        );
                    if (err != noErr)
                    {
                        NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"Failed to execute request in helper: %ld.\n", (long) err], nil, nil, nil);
                    }
                }
            } else {
                err = userCanceledErr;
            }
        }	
        
        // If the above went OK, it means that the IPC to the helper tool worked.  We 
        // now have to check the response dictionary to see if the command's execution 
        // within the helper tool was successful.  For the GetVersion command, this 
        // is unlikely to ever fail, but we should still check. 
        
        if (err == noErr) {
            err = BASGetErrorFromResponse(response);
            if (err != noErr)
            {
                NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"Failed to get response error: %ld.\n", (long) err], nil, nil, nil);
            }
        }
        else
        {
        }
        
        // Log our results.
        if (err == noErr) {
        } else {
            NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"Failed with error %ld.\n", (long) err], nil, nil, nil);
        }
        
        if (response != NULL) {
            CFRelease(response);
        }        
    }
    return err == noErr;
}

- (void)sleepSystem
{
    OSStatus        err;
    NSString *      bundleID;
    NSDictionary *  request;
    CFDictionaryRef response;
    BASFailCode     failCode;
	
    response = NULL;
	
    // Create our request.  Note that NSDictionary is toll-free bridged to CFDictionary, so 
    // we can use an NSDictionary as our request.  Also, if the "Force failure" checkbox is 
    // checked, we use the wrong command ID to deliberately cause an "unknown command" error 
    // so that we can test that code path.
    
	request = [NSDictionary dictionaryWithObjectsAndKeys:
			   @kWakerSleepSystemEventCommand, @kBASCommandKey,
			   nil];
	
    assert(request != NULL);
    
    bundleID = [[NSBundle mainBundle] bundleIdentifier];
    assert(bundleID != NULL);
    
    // Execute it.
    
	err = BASExecuteRequestInHelperTool(
										gAuth, 
										kWakerCommandSet, 
										(CFStringRef) bundleID, 
										(CFDictionaryRef) request, 
										&response
										);
	
    // If it failed, try to recover.
	if (err == noErr) {
        err = BASGetErrorFromResponse(response);
	}

    if ( (err != noErr) && (err != userCanceledErr) ) {
        int alertResult;
        
        failCode = BASDiagnoseFailure(gAuth, (CFStringRef) bundleID);
		
        // At this point we tell the user that something has gone wrong and that we need 
        // to authorize in order to fix it.  Ideally we'd use failCode to describe the type of 
        // error to the user.
		
        alertResult = NSRunAlertPanel(@"Needs Install", @"Waker needs to install the wake up tool", nil, nil, nil);
        
        if ( alertResult == NSAlertDefaultReturn ) {
            // Try to fix things.
            
            err = BASFixFailure(gAuth, (CFStringRef) bundleID, CFSTR("InstallTool"), CFSTR("HelperTool"), failCode);
			if (err != noErr)
			{
				NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"Failed to fix failure: %ld.\n", (long) err], nil, nil, nil);
			}
			
            // If the fix went OK, retry the request.
            
            if (err == noErr) {
                err = BASExecuteRequestInHelperTool(
													gAuth, 
													kWakerCommandSet, 
													(CFStringRef) bundleID, 
													(CFDictionaryRef) request, 
													&response
													);
				if (err != noErr)
				{
					NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"Failed to execute request in helper: %ld.\n", (long) err], nil, nil, nil);
				}
            }
        } else {
            err = userCanceledErr;
        }
    }	
    
    // If the above went OK, it means that the IPC to the helper tool worked.  We 
    // now have to check the response dictionary to see if the command's execution 
    // within the helper tool was successful.  For the GetVersion command, this 
    // is unlikely to ever fail, but we should still check. 
    
    if (err == noErr) {
        err = BASGetErrorFromResponse(response);
		if (err != noErr)
		{
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"Failed to get response error: %ld.\n", (long) err], nil, nil, nil);
		}
    }
	else
	{
	}
    
    // Log our results.
    if (err == noErr) {
    } else {
		NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"Failed with error %ld.\n", (long) err], nil, nil, nil);
    }
    
    if (response != NULL) {
        CFRelease(response);
    }
}

- (bool)destroyRights
    // Called when the user chooses the "Destroy Rights" menu item.  This is just a testing 
    // convenience; it allows you to destroy the credentials that are stored in the cache 
    // associated with gAuth, so you can force the system to ask you for a password again.  
    // However, this isn't as convenient as you might think because the credentials might 
    // be cached globally.  See DTS Q&A 1277 "Security Credentials" for the gory details.
    //
    // <http://developer.apple.com/qa/qa2001/qa1277.html>
{
    OSStatus    junk;
    
    // Free gAuth, destroying any credentials that it has acquired along the way. 
    
    junk = AuthorizationFree(gAuth, kAuthorizationFlagDestroyRights);
    assert(junk == noErr);
    gAuth = NULL;

    // Recreate it from scratch.
    
    junk = AuthorizationCreate(NULL, NULL, kAuthorizationFlagDefaults, &gAuth);
    assert(junk == noErr);
    assert( (junk == noErr) == (gAuth != NULL) );
	
    return junk == noErr;
}

- (float)volume 
{
	Float32			outputVolume;
	
	UInt32 propertySize = 0;
	OSStatus status = noErr;
	AudioObjectPropertyAddress propertyAOPA;
	propertyAOPA.mElement = kAudioObjectPropertyElementMaster;
	propertyAOPA.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume;
	propertyAOPA.mScope = kAudioDevicePropertyScopeOutput;
	
	AudioDeviceID outputDeviceID = [self defaultOutputDeviceID];
	
	if (outputDeviceID == kAudioObjectUnknown)
	{
		NSLog(@"Unknown device");
		return 0.0;
	}
	
	if (!AudioHardwareServiceHasProperty(outputDeviceID, &propertyAOPA))
	{
		NSLog(@"No volume returned for device 0x%0x", outputDeviceID);
		return 0.0;
	}
	
	propertySize = sizeof(Float32);
	
	status = AudioHardwareServiceGetPropertyData(outputDeviceID, &propertyAOPA, 0, NULL, &propertySize, &outputVolume);
	
	if (status)
	{
		NSLog(@"No volume returned for device 0x%0x", outputDeviceID);
		return 0.0;
	}
	
	if (outputVolume < 0.0 || outputVolume > 1.0) return 0.0;
	
	return outputVolume;
}

// setting system volume - mutes if under threshhold 
- (void)setVolume:(Float32)newVolume
{
	if (newVolume < 0.0 || newVolume > 1.0)
	{
		NSLog(@"Requested volume out of range (%.2f)", newVolume);
		return;
		
	}
	
	// get output device device
	UInt32 propertySize = 0;
	OSStatus status = noErr;
	AudioObjectPropertyAddress propertyAOPA;
	propertyAOPA.mElement = kAudioObjectPropertyElementMaster;
	propertyAOPA.mScope = kAudioDevicePropertyScopeOutput;
	
	if (newVolume < 0.001)
	{
		//NSLog(@"Requested mute");
		propertyAOPA.mSelector = kAudioDevicePropertyMute;
		
	}
	else
	{
		//NSLog(@"Requested volume %.2f", newVolume);
		propertyAOPA.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume;
	}
	
	AudioDeviceID outputDeviceID = [self defaultOutputDeviceID];
	
	if (outputDeviceID == kAudioObjectUnknown)
	{
		NSLog(@"Unknown device");
		return;
	}
	
	if (!AudioHardwareServiceHasProperty(outputDeviceID, &propertyAOPA))
	{
		NSLog(@"Device 0x%0x does not support volume control", outputDeviceID);
		return;
	}
	
	Boolean canSetVolume = NO;
	
	status = AudioHardwareServiceIsPropertySettable(outputDeviceID, &propertyAOPA, &canSetVolume);
	
	if (status || canSetVolume == NO)
	{
		NSLog(@"Device 0x%0x does not support volume control", outputDeviceID);
		return;
	}
	
	if (propertyAOPA.mSelector == kAudioDevicePropertyMute)
	{
		propertySize = sizeof(UInt32);
		UInt32 mute = 1;
		status = AudioHardwareServiceSetPropertyData(outputDeviceID, &propertyAOPA, 0, NULL, propertySize, &mute);		
	}
	else
	{
		propertySize = sizeof(Float32);
		
		status = AudioHardwareServiceSetPropertyData(outputDeviceID, &propertyAOPA, 0, NULL, propertySize, &newVolume);	
		
		if (status)
		{
			NSLog(@"Unable to set volume for device 0x%0x", outputDeviceID);
		}
		
		// make sure we're not muted
		propertyAOPA.mSelector = kAudioDevicePropertyMute;
		propertySize = sizeof(UInt32);
		UInt32 mute = 0;
		
		if (!AudioHardwareServiceHasProperty(outputDeviceID, &propertyAOPA))
		{
			NSLog(@"Device 0x%0x does not support muting", outputDeviceID);
			return;
		}
		
		Boolean canSetMute = NO;
		
		status = AudioHardwareServiceIsPropertySettable(outputDeviceID, &propertyAOPA, &canSetMute);
		
		if (status || !canSetMute)
		{
			NSLog(@"Device 0x%0x does not support muting", outputDeviceID);
			return;
		}
		
		status = AudioHardwareServiceSetPropertyData(outputDeviceID, &propertyAOPA, 0, NULL, propertySize, &mute);
	}
	
	if (status)
	{
		NSLog(@"Unable to set volume for device 0x%0x", outputDeviceID);
	}
	
}

- (AudioDeviceID)defaultOutputDeviceID
{
	AudioDeviceID	outputDeviceID = kAudioObjectUnknown;
	
	// get output device device
	UInt32 propertySize = 0;
	OSStatus status = noErr;
	AudioObjectPropertyAddress propertyAOPA;
	propertyAOPA.mScope = kAudioObjectPropertyScopeGlobal;
	propertyAOPA.mElement = kAudioObjectPropertyElementMaster;
	propertyAOPA.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
	
	if (!AudioHardwareServiceHasProperty(kAudioObjectSystemObject, &propertyAOPA))
	{
		NSLog(@"Cannot find default output device!");
		return outputDeviceID;
	}
	
	propertySize = sizeof(AudioDeviceID);
	
	status = AudioHardwareServiceGetPropertyData(kAudioObjectSystemObject, &propertyAOPA, 0, NULL, &propertySize, &outputDeviceID);
	
	if(status) 
	{
		NSLog(@"Cannot find default output device!");
	}
	return outputDeviceID;
}

- (NSWindow*)QSShowLargeType:(NSString*)inString
{
    return QSShowLargeType(inString);
}

- (long)idleTimeSeconds
{
	mach_port_t masterPort;
	io_iterator_t iter;
	io_registry_entry_t curObj;
	
	IOMasterPort(MACH_PORT_NULL, &masterPort);
	
	/* Get IOHIDSystem */
	IOServiceGetMatchingServices(masterPort,
								 IOServiceMatching("IOHIDSystem"),
								 &iter);
	if (iter == 0) {
		printf("Error accessing IOHIDSystem\n");
		exit(1);
	}
	
	curObj = IOIteratorNext(iter);
	
	if (curObj == 0) {
		printf("Iterator's empty!\n");
		exit(1);
	}
	
	CFMutableDictionaryRef properties = 0;
	CFTypeRef obj;
	
	if (IORegistryEntryCreateCFProperties(curObj, &properties,
										  kCFAllocatorDefault, 0) ==
		KERN_SUCCESS && properties != NULL) {
		
		obj = CFDictionaryGetValue(properties, CFSTR("HIDIdleTime"));
		CFRetain(obj);
	} else {
		printf("Couldn't grab properties of system\n");
		obj = NULL;
	}
	
	uint64_t tHandle = 0;
	if (obj) {
		
		CFTypeID type = CFGetTypeID(obj);
		
		if (type == CFDataGetTypeID()) {
			CFDataGetBytes((CFDataRef) obj,
						   CFRangeMake(0, sizeof(tHandle)),
						   (UInt8*) &tHandle);
		}  else if (type == CFNumberGetTypeID()) {
			CFNumberGetValue((CFNumberRef)obj,
							 kCFNumberSInt64Type,
							 &tHandle);
		} else {
			printf("%d: unsupported type\n", (int)type);
			exit(1);
		}
		
		CFRelease(obj);
		
		// essentially divides by 10^9
		tHandle >>= 30;
		//printf("%qi\n", tHandle);
	} else {
		printf("Can't find idle time\n");
	}
	
	/* Release our resources */
	IOObjectRelease(curObj);
	IOObjectRelease(iter);
	CFRelease((CFTypeRef)properties);
	return tHandle;
}

- (void)testAbsoluteTimeConversion:(double)t
{
    double diff = CFAbsoluteTimeGetCurrent()-t;
    NSLog(@"testAbsoluteTimeConversion: this number should be very close to 0: %.2f", diff);
    assert(diff < 0.5);
}

@end

/*int main(int argc, char *argv[])
{
    OSStatus    junk;
    
    // Create the AuthorizationRef that we'll use through this application.  We ignore 
    // any error from this.  A failure from AuthorizationCreate is very unusual, and if it 
    // happens there's no way to recover; Authorization Services just won't work.

    junk = AuthorizationCreate(NULL, NULL, kAuthorizationFlagDefaults, &gAuth);
    assert(junk == noErr);
    assert( (junk == noErr) == (gAuth != NULL) );

	// For each of our commands, check to see if a right specification exists and, if not,
    // create it.
    //
    // The last parameter is the name of a ".strings" file that contains the localised prompts 
    // for any custom rights that we use.
    
	BASSetDefaultRules(
		gAuth, 
		kWakerCommandSet, 
		CFBundleGetIdentifier(CFBundleGetMainBundle()), 
		CFSTR("WakerPrompts")
	);
    
    // And now, the miracle that is Cocoa...
    
    return NSApplicationMain(argc,  (const char **) argv);
}*/
