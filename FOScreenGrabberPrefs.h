//
//  FOScreenGrabberPrefs.h
//  ScreenGrabber
//
//  Created by Fredrik Olsson on 2006-08-12.
//  Copyright 2006 Fredrik Olsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define FOPrefs [FOScreenGrabberPrefs standardPrefs]

@interface FOScreenGrabberPrefs : NSObject 
{
}

+ (FOScreenGrabberPrefs *)standardPrefs;

- (float)imageWidth;
- (float)gridSize;
- (NSString *)imageType;
- (BOOL)addMovieInfo;
- (BOOL)addTimestamp;
- (BOOL)addBorder;
- (float)borderWidth;
- (NSColor *)backgroundColor;
- (NSColor *)fontColor;

@end
