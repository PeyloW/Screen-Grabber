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

@interface QTTrack (PrivateAdditions)

-(QTMedia*)foMedia;

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

- (NSString *)videoKbps
{
	NSString *result = @"?";
    NSArray *tracks;
    if ([self haveMPEGTrack]) {
        tracks = [self tracksOfMediaType:QTMediaTypeMPEG];
    } else {
        tracks = [self tracksOfMediaType:QTMediaTypeVideo];
    }
    if ([tracks count] > 0) {
		QTTrack *track = [tracks objectAtIndex:0];
		float seconds = [self _durationInSeconds];
		SInt64 size = [[track foMedia] mediaSize];
		if (size > 0) {
			float kbps = (size / (1024.0 / 8.0)) / seconds;
			result = [NSString stringWithFormat:@"%.2f", kbps, nil];
		}
	}
	return result;
}

- (NSString *)videoCodec
{
    NSString *result = @"<Unknown codec>";
    if ([self haveMPEGTrack]) {
        return @"MPEG1 Muxed";
    }
    NSArray *tracks = [self tracksOfMediaType:QTMediaTypeVideo];
    if ([tracks count] > 0) {
        QTMedia *media = [[tracks objectAtIndex:0] media];
        ImageDescriptionHandle desc = (ImageDescriptionHandle)NewHandleClear(sizeof(ImageDescription));
        if (desc) {
            GetMediaSampleDescription([media quickTimeMedia], 1, (SampleDescriptionHandle)desc);
            OSErr err = GetMoviesError();
            if (err == noErr) {
                result = [NSString stringWithCString:p2cstr((**desc).name) encoding:NSASCIIStringEncoding];
                if ([result length] == 0) {
					CodecInfo info;
					err = GetCodecInfo(&info, (**desc).cType, 0);
					if (err == noErr) {
						result = [NSString stringWithCString:p2cstr(info.typeName) encoding:NSASCIIStringEncoding];
					} else {
						char *bytes = (char *)&((**desc).cType);
						result = [NSString stringWithFormat:@"%c%c%c%c", bytes[0], bytes[1], bytes[2], bytes[3], nil];
					}
				}
            }
            DisposeHandle((Handle)desc);
        }
    }
    return result;
}

- (NSString *)audioFrequenzy
{
    NSString *result = @"?";
    NSArray *tracks = [self tracksOfMediaType:QTMediaTypeSound];
    if ([tracks count] > 0) {
        QTMedia *media = [[tracks objectAtIndex:0] foMedia];
        long scale = [[media attributeForKey:QTMediaTimeScaleAttribute] longValue];
        result = [NSString stringWithFormat:@"%g", scale];
    }
    return result;
}

- (NSString *)audioKbps
{
	NSString *result = @"?";
    NSArray *tracks = [self tracksOfMediaType:QTMediaTypeSound];
    if ([tracks count] > 0) {
		QTTrack *track = [tracks objectAtIndex:0];
		float seconds = [self _durationInSeconds];
		SInt64 size = [[track media] mediaSize];
		if (size > 0) {
			float kbps = (size / (1024.0 / 8.0)) / seconds;
			result = [NSString stringWithFormat:@"%.2f", kbps, nil];
		}
	}
	return result;
}

- (NSString *)audioCodec
{
    NSString *result = @"<Unknown codec>";
    NSArray *tracks = [self tracksOfMediaType:QTMediaTypeSound];
    if ([tracks count] > 0) {
        QTMedia *media = [[tracks objectAtIndex:0] media];
        SoundDescriptionHandle desc = (SoundDescriptionHandle)NewHandleClear(sizeof(SoundDescriptionHandle));
        if (desc) { 
            GetMediaSampleDescription([media quickTimeMedia], 1, (SampleDescriptionHandle)desc);
            OSErr err = GetMoviesError();
            if (err == noErr) {
				CFStringRef strTemp;
				err = QTSoundDescriptionGetProperty(desc, kQTPropertyClass_Audio, kQTAudioPropertyID_FormatString, sizeof(strTemp), &strTemp, NULL);
				if (err == noErr) {
					result = (NSString *)strTemp;
				}
			}
            DisposeHandle((Handle)desc);
        }
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

@implementation QTTrack (PrivateAdditions)

-(QTMedia*)foMedia;
{
    QTMedia* media = [self media];
    if (media == nil) {
        NSString* desc = [self description];
        NSRange range = [desc rangeOfString:@"QTMedia =" options:NSBackwardsSearch];
        if (range.location != NSNotFound) {
            desc = [desc substringFromIndex:range.location+range.length];
            unsigned long long pointer = 0;
            if ([[NSScanner scannerWithString:desc] scanHexLongLong:&pointer]) {
                media = (id)pointer;
            }
        }
    }
    return media;
}

@end


@implementation QTMedia (PrivateAdditions)

- (SInt64)mediaSize
{
    return [[self attributeForKey:QTMediaSampleCountAttribute] longLongValue];
}

@end
