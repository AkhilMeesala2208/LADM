//
//  LADMCore.h
//  LADMCore
//
//  Created by Guilherme Rambo on 23/02/21.
//

#import <Foundation/Foundation.h>

//! Project version number for LADMCore.
FOUNDATION_EXPORT double LADMCoreVersionNumber;

//! Project version string for LADMCore.
FOUNDATION_EXPORT const unsigned char LADMCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <LADMCore/PublicHeader.h>

extern int SLSGetAppearanceThemeLegacy(void);
extern void SLSSetAppearanceThemeLegacy(int);

#define kLADMCoreSubsystemName "com.akhilmeesala.LADMCore"

#import <LADMCore/LADMAmbientLightSensor.h>
#import <LADMCore/SharedFileList.h>
