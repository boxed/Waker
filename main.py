# coding=UTF-8

#import modules required by application
import objc
import Foundation
import AppKit
import CoreData

from PyObjCTools import AppHelper

# import modules containing classes required to start application and load MainMenu.nib
import Waker_AppDelegate
import transformers

import os
os.putenv("USE_PDB", "1")
objc.setVerbose(True)

import os
import sys
#print 'CWD:',os.path.join(os.gprint 'CWD:',os.path.join(Foundation.NSBundle.mainBundle().resourcePath(), 'appscript-1.0.0-py2.7-macosx-10.7-intel.egg')
sys.path.append(os.path.join(Foundation.NSBundle.mainBundle().resourcePath(), 'appscript-1.0.0-py2.7-macosx-10.7-intel.egg'))
# pass control to AppKit
AppHelper.runEventLoop()
