//
//  QTMovieAdditions.m
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

#import "QTMovieAdditions.h"

@interface QTMovie (PrivateAdditions)

- (float)_durationInSeconds;

@end


@interface QTMedia (PrivateAdditions)

- (SInt64)mediaSize; 

@end

@implementation QTMovie (Additions)

- (NSString *)movieName
{
    return [[[self movieAttributes] objectForKey:QTMovieFileNameAttribute] lastPathComponent];
}

- (NSString *)movieDuration
{
    return [QTStringFromTime([self duration]) substringWithRange:NSMakeRange(2, 8)];
}

- (BOOL)haveMPEGTrack
{
    NSArray *tracks = [self tracksOfMediaType:QTMediaTypeMPEG];
    return tracks && ([tracks count] > 0);
}

- (BOOL)haveVideoTrack
{
    NSArray *tracks = [self tracksOfMediaType:QTMediaTypeVideo];
    return tracks && ([tracks count] > 0);
}

- (BOOL)haveAudioTrack
{
    NSArray *tracks = [self tracksOfMediaType:QTMediaTypeSound];
    return tracks && ([tracks count] > 0);
}

- (NSSize)naturalSize;
{
    return [[self attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];
}

- (NSString *)videoResolution
{
    NSSize size = [self naturalSize];
    return [NSString stringWithFormat:@"%dx%d", (int)size.width, (int)size.height, nil];
}

- (NSString *)videoDescription;
{
    NSString *result = @"<Unknown video codec>";
    QTTrack *track;
    if ([self haveMPEGTrack]) {
        track = [[self tracksOfMediaType:QTMediaTypeMPEG] lastObject];
    } else {
        track = [[self tracksOfMediaType:QTMediaTypeVideo] lastObject];
    }
    if (track) {
        result = [track attributeForKey:QTTrackFormatSummaryAttribute];
        //long sampleCount = [[[track media] attributeForKey:QTMediaSampleCountAttribute] longValue];
        //result = [result stringByAppendingFormat:@", %.fkbit/s", sampleCount / (1024.0 / 8)];
    }
    return result;
}

- (NSString *)audioDescription;
{
    NSString *result = @"<Unknown audio codec>";
    QTTrack *track = [[self tracksOfMediaType:QTMediaTypeSound] lastObject];
    if (track) {
        result = [track attributeForKey:QTTrackFormatSummaryAttribute];
        //long sampleCount = [[[track media] attributeForKey:QTMediaSampleCountAttribute] longValue];
        //result = [result stringByAppendingFormat:@", %.fkbit/s", sampleCount / (1024.0 / 8)];
    }
    return result;
}

-(QTMovieLoadState)loadState;
{
    return [[self attributeForKey:QTMovieLoadStateAttribute] integerValue];
}

-(BOOL)waitForLoadState:(QTMovieLoadState)loadState;
{
    QTMovieLoadState actualLoadState = [self loadState];
    while (actualLoadState != QTMovieLoadStateError && actualLoadState < loadState) {
        if ([NSThread isMainThread]) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        } else {
            [NSThread sleepForTimeInterval:0.5];
        }
        actualLoadState = [self loadState];
    }
    if (actualLoadState == QTMovieLoadStateError) {
        NSError* error = [self attributeForKey:QTMovieLoadStateErrorAttribute];
        NSLog(@"Load state error: %@", error);
        return NO;
    }
    return YES;
}

@end

@implementation QTMovie (PrivateAdditions)

- (float)_durationInSeconds
{
    NSString *duration = [self movieDuration];
    if (duration) {
        NSArray *durationParts = [duration componentsSeparatedByString:@":"];
        if ([durationParts count] == 3) {
            float result = [[durationParts objectAtIndex:0] floatValue];
            result = result * 60 + [[durationParts objectAtIndex:1] floatValue];
            return result * 60 + [[durationParts objectAtIndex:2] floatValue];
        }
    }
    return 0.0;
}

@end


@implementation QTMedia (PrivateAdditions)

- (SInt64)mediaSize
{
    for (NSString *key in [self attributeKeys]) {
        NSLog(@"%@ : '%@'", key, [self attributeForKey:key]);
    }
	return 0;
}

@end
