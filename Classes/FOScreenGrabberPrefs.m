//
//  FOScreenGrabberPrefs.m
//  ScreenGrabber
//
//  Copyright 2006-2011 Fredrik Olsson. All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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

- (float)gridCols;
{
    return [[self userDefaults] floatForKey:@"gridCols"];
}

- (float)gridRows;
{
    return [[self userDefaults] floatForKey:@"gridRows"];    
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

- (BOOL)addWatermark;
{
	return [[self userDefaults] boolForKey:@"addWatermark"];
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
    [values setObject:[NSNumber numberWithFloat:3] forKey:@"gridCols"];
    [values setObject:[NSNumber numberWithFloat:8] forKey:@"gridRows"];
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
