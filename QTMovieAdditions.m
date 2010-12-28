//
//  QTMovieAdditions.m
//  ScreenGrabber
//
//  Created by Fredrik Olsson on 2006-08-15.
//  Copyright 2006 Fredrik Olsson. All rights reserved.
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

- (NSString *)videoResolution
{
    NSSize size = [[[self movieAttributes] objectForKey:QTMovieNaturalSizeAttribute] sizeValue];
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
		SInt64 size = [[track media] mediaSize];
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
                result = [NSString stringWithCString:p2cstr((**desc).name)];
                if ([result length] == 0) {
					CodecInfo info;
					err = GetCodecInfo(&info, (**desc).cType, 0);
					if (err == noErr) {
						result = [NSString stringWithCString:p2cstr(info.typeName)];
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
        QTMedia *media = [[tracks objectAtIndex:0] media];
        SoundDescriptionHandle desc = (SoundDescriptionHandle)NewHandleClear(sizeof(SoundDescriptionHandle));
        if (desc) {
            GetMediaSampleDescription([media quickTimeMedia], 1, (SampleDescriptionHandle)desc);
            OSErr err = GetMoviesError();
            if (err == noErr) {
                result = [NSString stringWithFormat:@"%g", ((**desc).sampleRate >> 16) / 1000.0, nil];
            }
            DisposeHandle((Handle)desc);
        }
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



- (NSImage *)imageAtTime:(QTTime)qttime
{
    TimeValue time = (TimeValue)qttime.timeValue;
    Movie movie = [self quickTimeMovie];
    // Pin the time to legal values.
    TimeValue duration = GetMovieDuration(movie);
    if (time > duration)
        time = duration;
    if (time < 0) time = 0;
    
    // Create an offscreen GWorld for the movie to draw into.
    GWorldPtr gworld = [self gworldForMovie:movie];
    
    // Set the GWorld for the movie.
    GDHandle oldDevice;
    CGrafPtr oldPort;
    GetMovieGWorld(movie,&oldPort,&oldDevice);
    SetMovieGWorld(movie,gworld,GetGWorldDevice(gworld));
    
    // Advance the movie to the appropriate time value.
    SetMovieTimeValue(movie,time);
    
    // Draw the movie.
    UpdateMovie(movie);
    MoviesTask(movie,0);
    
    // Create an NSImage from the GWorld.
    NSImage *image = [self imageFromGWorld:gworld];
    
    // Restore the previous GWorld, then dispose the one we allocated.
    SetMovieGWorld(movie,oldPort,oldDevice);
    DisposeGWorld(gworld);
    
    return image;
}



// ---------------------------------------
// gworldForMovie:
// ---------------------------------------
//  Get the bounding rectangle of the Movie the create a 32-bit GWorld
//  with those dimensions.
//  This GWorld will be used for rendering Movie frames into.

-(GWorldPtr) gworldForMovie:(Movie)movie
{
    Rect        srcRect;
    GWorldPtr   newGWorld = NULL;
    CGrafPtr    savedPort;
    GDHandle    savedDevice;
    
    OSErr err = noErr;
    GetGWorld(&savedPort, &savedDevice);
    
    GetMovieBox(movie,&srcRect);
    
    err = NewGWorld(&newGWorld,
                    k32ARGBPixelFormat,
                    &srcRect,
                    NULL,
                    NULL,
                    0);
    if (err == noErr)
    {
        if (LockPixels(GetGWorldPixMap(newGWorld)))
        {
            Rect        portRect;
            RGBColor    theBlackColor   = { 0, 0, 0 };
            RGBColor    theWhiteColor   = { 65535, 65535, 65535 };
            
            SetGWorld(newGWorld, NULL);
            GetPortBounds(newGWorld, &portRect);
            RGBBackColor(&theBlackColor);
            RGBForeColor(&theWhiteColor);
            EraseRect(&portRect);
            
            UnlockPixels(GetGWorldPixMap(newGWorld));
        }
    }
    
    SetGWorld(savedPort, savedDevice);
    NSAssert(newGWorld != NULL, @"NULL gworld");
    return newGWorld;
}



-(NSImage *)imageFromGWorld:(GWorldPtr) gWorldPtr
{
    PixMapHandle        pixMapHandle = NULL;
    Ptr                 pixBaseAddr = nil;
    NSBitmapImageRep    *imageRep = nil;
    NSImage             *image = nil;
    
    NSAssert(gWorldPtr != nil, @"nil gWorldPtr");
    
    // Lock the pixels
    pixMapHandle = GetGWorldPixMap(gWorldPtr);
    if (pixMapHandle)
    {
        Rect        portRect;
        unsigned    portWidth, portHeight;
        int         bitsPerSample, samplesPerPixel;
        BOOL        hasAlpha, isPlanar;
        int         destRowBytes;
        
        NSAssert(LockPixels(pixMapHandle) != false, @"LockPixels returns false");
        
        GetPortBounds(gWorldPtr, &portRect);
        portWidth = (portRect.right - portRect.left);
        portHeight = (portRect.bottom - portRect.top);
        
        bitsPerSample   = 8;
        samplesPerPixel = 4;
        hasAlpha        = YES;
        isPlanar        = NO;
        destRowBytes    = portWidth * samplesPerPixel;
        imageRep        = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL 
                                                                  pixelsWide:portWidth 
                                                                  pixelsHigh:portHeight 
                                                               bitsPerSample:bitsPerSample 
                                                             samplesPerPixel:samplesPerPixel 
                                                                    hasAlpha:hasAlpha 
                                                                    isPlanar:NO
                                                              colorSpaceName:NSDeviceRGBColorSpace 
                                                                 bytesPerRow:destRowBytes 
                                                                bitsPerPixel:0];
        if (imageRep)
        {
            char    *theData;
            int     pixmapRowBytes;
            int     rowByte,rowIndex;
            
            theData = [imageRep bitmapData];
            
            pixBaseAddr = GetPixBaseAddr(pixMapHandle);
            if (pixBaseAddr)
            {
                pixmapRowBytes = GetPixRowBytes(pixMapHandle);
                
                for (rowIndex=0; rowIndex< portHeight; rowIndex++)
                {
                    unsigned char *dst = theData + rowIndex * destRowBytes;
                    unsigned char *src = pixBaseAddr + rowIndex * pixmapRowBytes;
                    unsigned char a,r,g,b;
                    
                    for (rowByte = 0; rowByte < portWidth; rowByte++)
                    {
                        a = *src++;     // get source Alpha component
                        r = *src++;     // get source Red component
                        g = *src++;     // get source Green component
                        b = *src++;     // get source Blue component  
                        
                        *dst++ = r;     // set dest. Alpha component
                        *dst++ = g;     // set dest. Red component
                        *dst++ = b;     // set dest. Green component
                        *dst++ = a;     // set dest. Blue component  
                    }
                }
                
                image = [[NSImage alloc] initWithSize:NSMakeSize(portWidth, portHeight)];
                if (image)
                {
                    [image addRepresentation:imageRep];
                }
            }
        }
    }
    
    NSAssert(pixMapHandle != NULL, @"null pixMapHandle");
    NSAssert(imageRep != nil, @"nil imageRep");
    NSAssert(pixBaseAddr != nil, @"nil pixBaseAddr");
    NSAssert(image != nil, @"nil image");
    
    if (pixMapHandle)
    {
        UnlockPixels(pixMapHandle);
    }
    
    return image;
}


@end

@implementation QTMedia (PrivateAdditions)

- (SInt64)mediaSize
{
	Media media = [self quickTimeMedia];
	SInt64 size;
	TimeValue64 start = GetMediaDisplayStartTime(media);
	TimeValue64 duration = GetMediaDisplayDuration(media);
	OSErr err = GetMediaDataSizeTime64(media, start, duration, &size);
	if (err == noErr) {
		return size;
	}
	return 0;
}

@end
