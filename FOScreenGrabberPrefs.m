//
//  FOScreenGrabberPrefs.m
//  ScreenGrabber
//
//  Created by Fredrik Olsson on 2006-08-12.
//  Copyright 2006 Fredrik Olsson. All rights reserved.
//

#import "FOScreenGrabberPrefs.h"
#import "FOApplicationController.h"

@interface FOApplicationController (LoadPrefs)

+ (void)initialize;

@end

@implementation FOScreenGrabberPrefs

+ (FOScreenGrabberPrefs *)standardPrefs
{
    static FOScreenGrabberPrefs *_me = nil;
    if (!_me) {
        _me = [[FOScreenGrabberPrefs alloc] init];
    }
    return _me;
}

- (NSUserDefaults *)userDefaults
{
    return [[NSUserDefaultsController sharedUserDefaultsController] defaults];
}


- (float)imageWidth 
{
    return [[self userDefaults] floatForKey:@"imageWidth"];
}

- (float)gridSize
{
    return [[self userDefaults] floatForKey:@"gridSize"];
}

- (NSString *)imageType
{
    return [[self userDefaults] stringForKey:@"imageType"];
}

- (BOOL)addMovieInfo
{
    return [[self userDefaults] boolForKey:@"addMovieInfo"];
}

- (BOOL)addTimestamp;
{
    return [[self userDefaults] boolForKey:@"addTimestamp"];
}

- (BOOL)addBorder;
{
    return [[self userDefaults] boolForKey:@"addBorder"];
}

- (float)borderWidth;
{
    return [[self userDefaults] floatForKey:@"borderWidth"];
}

- (NSColor *)backgroundColor
{
    return [NSUnarchiver unarchiveObjectWithData:[[self userDefaults] objectForKey: @"backgroundColor"]];
}

- (NSColor *)fontColor
{
    return [NSUnarchiver unarchiveObjectWithData:[[self userDefaults] objectForKey: @"fontColor"]];
}

@end


@implementation FOApplicationController (LoadPrefs)

+ (void)initialize
{
    [FOScreenGrabberPrefs standardPrefs];
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithCapacity:8];
    [values setObject:[NSNumber numberWithFloat:480.0] forKey:@"imageWidth"];
    [values setObject:[NSNumber numberWithFloat:520.0] forKey:@"gridSize"];
    [values setObject:@"jpeg" forKey:@"imageType"];
    [values setObject:[NSNumber numberWithBool:YES] forKey:@"addMovieInfo"];
    [values setObject:[NSNumber numberWithBool:YES] forKey:@"addTimestamp"];
    [values setObject:[NSNumber numberWithBool:YES] forKey:@"addBorder"];
    [values setObject:[NSNumber numberWithFloat:2.0] forKey:@"borderWidth"];
    NSColor *color = [NSColor colorWithDeviceWhite:0.5 alpha:1.0];
    [values setObject:[NSArchiver archivedDataWithRootObject:color] forKey:@"backgroundColor"];
    color = [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
    [values setObject:[NSArchiver archivedDataWithRootObject:color] forKey:@"fontColor"];
    NSUserDefaultsController *cnt = [NSUserDefaultsController sharedUserDefaultsController];
    [[cnt defaults] registerDefaults:values];
    [cnt save:self];
    
    [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
}

@end
