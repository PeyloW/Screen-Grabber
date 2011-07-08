//
//  FOScreenGrabber.m
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

#import "FOScreenGrabber.h"

#import "FOScreenGrabberPrefs.h"
#import <xpc/xpc.h>

static void dispatch_sync_on_main_queue(dispatch_block_t b) {
    if ([NSThread isMainThread]) 
        b(); 
    else 
        dispatch_sync(dispatch_get_main_queue(), b);
}

@interface FOScreenGrabber (Private)

- (void)_setImage:(NSImage *)image;

- (void)_setProcessing:(BOOL)processing;
- (void)_setPercentDone:(float)percentDone;

- (void)_captureImagesInBackground;

@end

@implementation FOScreenGrabber

- (id)initWithURL:(NSURL *)url error:(NSError **)error
{
    NSSize size = NSMakeSize((int)[FOPrefs gridCols], (int)[FOPrefs gridRows]);
    float width = [FOPrefs imageWidth];
    return [self initWithURL:url gridSize:size imageWidth:width error:error];
}


- (id)initWithURL:(NSURL *)url gridSize:(NSSize)gridSize imageWidth:(float)imageWidth error:(NSError **)error;
{
    __block FOScreenGrabber* result = [super init];
    if (result) {
        dispatch_sync_on_main_queue(^(void) {
            [result setGridSize:gridSize];
            [result setImageWidth:imageWidth];
            NSDictionary* attr = [NSDictionary dictionaryWithObjectsAndKeys:
                                  url, QTMovieURLAttribute,
                                  [NSNumber numberWithBool:YES], QTMovieOpenForPlaybackAttribute,
                                  QTMovieApertureModeClean, QTMovieApertureModeAttribute, nil];
            QTMovie *movie = [QTMovie movieWithAttributes:attr error:error];
            if ([movie waitForLoadState:QTMovieLoadStateLoaded]) {
                [result setMovie:movie];
            } else {
                result = nil;
            }
        });
    }
    return result;
}

- (id)delegate
{
    return _delegate;
}

- (void)setDelegate:(id)delegate
{
    [self willChangeValueForKey:@"delegate"];
    _delegate = delegate;
    [self didChangeValueForKey:@"delegate"];
}

- (QTMovie *)previewMovie
{
	if (_previewMovie == nil) {
    	_previewMovie = [self movie]; //[[self movie] copy];
    }
    return _previewMovie;
}


- (QTMovie *)movie
{
    return _movie;
}

- (void)setMovie:(QTMovie *)movie
{
    dispatch_sync_on_main_queue(^(void) {
        [self willChangeValueForKey:@"movie"];
        [self willChangeValueForKey:@"previewMovie"];
        _movie = movie;
        [self didChangeValueForKey:@"previewMovie"];
        [self didChangeValueForKey:@"movie"];
    });
}

- (NSImage *)image
{
    return _image;
}

- (NSURL *)movieURL
{
    __block NSURL* result = nil;
    dispatch_sync_on_main_queue(^(void) {    
        result = [_movie attributeForKey:QTMovieURLAttribute];
    });
    return result;
}

- (NSURL *)imageURL
{
    if (_imageURL) {
        return _imageURL;
    } else {
        return [NSURL fileURLWithPath:[[[self movieURL] path] stringByAppendingPathExtension:[FOPrefs imageType]]];
    }
}

- (void)setImageURL:(NSURL *)url
{
    [self willChangeValueForKey:@"imageURL"];
    _imageURL = url;
    [self didChangeValueForKey:@"imageURL"];
}


- (NSSize)gridSize
{
    return _gridSize;
}

- (void)setGridSize:(NSSize)gridSize
{
    [self willChangeValueForKey:@"gridSize"];
    _gridSize = gridSize;
    [self didChangeValueForKey:@"gridSize"];
}

-(int)gridCols;
{
	return [self gridSize].width;
}

-(void)setGridCols:(int)v
{
	NSSize size = [self gridSize];
    size.width = v;
    [self setGridSize:size];
}

-(int)gridRows;
{
	return [self gridSize].height;
}

-(void)setGridRows:(int)v
{
	NSSize size = [self gridSize];
    size.height = v;
    [self setGridSize:size];
}

- (float)imageWidth
{
    return _imageWidth;
}

- (void)setImageWidth:(float)imageWidth
{
    [self willChangeValueForKey:@"imageWidth"];
    _imageWidth = imageWidth;
    [self didChangeValueForKey:@"imageWidth"];
}

- (BOOL)isProcessing
{
    return _isProcessing;
}

- (float)percentDone
{
    if (_percentDone <= 0.0) {
        return 0.0;
    } else {
        return _percentDone;
    }
}

- (BOOL)isIndeterminate
{
    return _percentDone == -1.0;
}



- (IBAction)captureImages:(id)sender
{
    [self performSelectorInBackground:@selector(_captureImagesInBackground) withObject:nil];
}

- (IBAction)captureImagesInThread:(id)sender
{
    [self performSelectorInBackground:@selector(_captureImagesInBackground) withObject:nil];
}

- (BOOL)saveImageData:(NSData *)data inXPCServiceWithError:(NSError **)error;
{
    BOOL success = YES;
    xpc_connection_t connection = xpc_connection_create("se.peylow.Screen-Grabber.imagesaver", NULL);
    xpc_connection_set_event_handler(connection, ^(xpc_object_t object) {
        char* description = xpc_copy_description(object);
        NSLog(@"event: %s", description);
        free(description);
    });
    xpc_connection_resume(connection);
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    
    xpc_dictionary_set_string(message, "url", [[[self imageURL] absoluteString] UTF8String]);
    const void* dataMem = [data bytes];
    void* sharedMem = mmap((void*)dataMem, [data length], PROT_READ|PROT_WRITE, MAP_ANON|MAP_SHARED, -1, 0);
    memcpy(sharedMem, dataMem, [data length]);
    xpc_object_t shmem = xpc_shmem_create(sharedMem, [data length]);
    xpc_dictionary_set_value(message, "data", shmem);
    xpc_release(shmem);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY) {
        success = xpc_dictionary_get_bool(reply, "success");
        if (!success) {
            size_t length = 0;
            const void* errorData = xpc_dictionary_get_data(reply, "error", &length);
            if (errorData && error) {
                NSData* data = [NSData dataWithBytes:errorData length:length];
                *error = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            }
        }
    } else {
        success = NO;
    }
    
    munmap(sharedMem, [data length]);        
    xpc_release(message);
    xpc_connection_cancel(connection);
    xpc_release(connection);
    
    return success;
}

- (IBAction)saveImage:(id)sender
{
    [self _setProcessing:YES];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[_image TIFFRepresentation]];
    NSData *data = nil;
    NSString *path = [[self imageURL] path];
    if ([path hasSuffix:@"png"]) {
        NSDictionary *props = [NSDictionary dictionary];
        data = [imageRep representationUsingType:NSPNGFileType properties:props];
    } else if ([path hasSuffix:@"jpg"] || [path hasSuffix:@"jpeg"]) {
        NSDictionary *props = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.75f] forKey:NSImageCompressionFactor];
        data = [imageRep representationUsingType:NSJPEGFileType properties:props];
    }
    NSError *error = nil;
    BOOL success = YES;
    if (data) {
        if (xpc_connection_create != NULL) {
            success = [self saveImageData:data inXPCServiceWithError:&error];
        } else {
            success = [data writeToURL:[self imageURL] options:NSAtomicWrite error:&error];
        }
        if (!success) {
            [_delegate screenGrabber:self error:error];
        }
    } else {
        success = NO;
    }
    if (!success){
        if (error == nil) {
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"Could not save image.", NSLocalizedDescriptionKey,
                                  @"Image could not be created and saved.", NSLocalizedFailureReasonErrorKey,
                                  nil];
            error = [NSError errorWithDomain:@"FOScreenGrabberDomain" code:1 userInfo:dict];
        }
        [_delegate screenGrabber:self error:error];
    }
    [self _setProcessing:NO];
}

@end

@implementation FOScreenGrabber (Private)

- (void)_setImage:(NSImage *)image
{
    dispatch_sync_on_main_queue(^(void) {
        [self willChangeValueForKey:@"image"];
        if (_image != image) {
            _image = image;
        }
        [self didChangeValueForKey:@"image"];
        if ([self isProcessing]) {
            [_delegate screenGrabber:self processingPartialImage:_image];
        }
    });
}

- (void)_setProcessing:(BOOL)processing
{
    dispatch_sync_on_main_queue(^(void) {
        [self willChangeValueForKey:@"processing"];
        if (_isProcessing != processing) {
            [self willChangeValueForKey:@"isIndeterminate"];
            _percentDone = -1.0;
            [self didChangeValueForKey:@"isIndeterminate"];
        }
        _isProcessing = processing;
        [self didChangeValueForKey:@"processing"];
    });
}

- (void)_setPercentDone:(float)percentDone
{
    dispatch_sync_on_main_queue(^(void) {
        [self willChangeValueForKey:@"percentDone"];
        if (_percentDone == -1.0) {
            [self willChangeValueForKey:@"isIndeterminate"];
            _percentDone = percentDone;
            [self didChangeValueForKey:@"isIndeterminate"];
        } else {
            _percentDone = percentDone;
        }
        [self didChangeValueForKey:@"percentDone"];
        if ([self isProcessing]) {
            [_delegate screenGrabber:self processingPercentDone:percentDone];
        }
    });
}

- (NSAttributedString *)_infoForMovie:(QTMovie *)movie
{
    __block NSMutableAttributedString *result = nil;
    dispatch_sync_on_main_queue(^(void) {
        NSString *name = [movie movieName];
        NSString *length = [movie movieDuration];
        NSString *video = @"\tVideo:\t";
        NSString *audio = @"\tAudio:\t";
        if ([movie haveVideoTrack] || [movie haveMPEGTrack]) {
            NSString *videoSize = [movie videoResolution];
            NSString *videoKbps = [movie videoKbps];
            NSString *videoCodec = [movie videoCodec];
            video = [video stringByAppendingFormat:@"%@pixels, %@kbit/s, %@", videoSize, videoKbps, videoCodec, nil];
        }
        if ([movie haveAudioTrack]) {
            NSString *audioHz = [movie audioFrequenzy];
            NSString *audioKbps = [movie audioKbps];
            NSString *audioCodec = [movie audioCodec];
            audio = [audio stringByAppendingFormat:@"%@kHz, %@kbit/s, %@", audioHz, audioKbps, audioCodec, nil];
        } else if ([movie haveMPEGTrack]) {
            audio = [audio stringByAppendingFormat:@"%@?", [movie videoCodec], nil];
        }
        NSString *text = [NSString stringWithFormat:@"%@ (%@)\n%@\n%@", name, length, video, audio, nil];
        
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        NSFont *font = [NSFont fontWithName:@"Lucida Grande Bold" size:12.0];
        [attrs setObject:font forKey:NSFontAttributeName];
        [attrs setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
        NSShadow *shadow = [[NSShadow alloc] init];
        [shadow setShadowOffset:NSMakeSize(1.0, -2.0)];
        [shadow setShadowBlurRadius:1.25];
        [shadow setShadowColor:[NSColor blackColor]];
        [attrs setObject:shadow forKey:NSShadowAttributeName];
        result = [[NSMutableAttributedString alloc] initWithString:text attributes:attrs];
        font = [NSFont fontWithName:@"Lucida Grande Bold" size:16.0];
        [attrs setObject:font forKey:NSFontAttributeName];
        [result setAttributes:attrs range:NSMakeRange(0, [text rangeOfString:@"\n"].location)];
    });
    return result;
}

- (NSAttributedString *)_timestampForTime:(QTTime)qttime
{
    NSString *time = QTStringFromTime(qttime);
    time = [time substringWithRange:NSMakeRange(2, 8)];
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    NSFont *font = [NSFont fontWithName:@"Lucida Grande" size:12.0];
    [attrs setObject:font forKey:NSFontAttributeName];
    [attrs setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowOffset:NSMakeSize(1.0, -2.0)];
    [shadow setShadowBlurRadius:1.25];
    [shadow setShadowColor:[NSColor blackColor]];
    [attrs setObject:shadow forKey:NSShadowAttributeName];
    return [[NSAttributedString alloc] initWithString:time attributes:attrs];
}


- (void)_captureImagesInBackground
{
    NSError* error = nil;
    BOOL success = YES;
    [_delegate performSelectorOnMainThread:@selector(screenGrabberWillCaptureImages:)
                                withObject:self 
                             waitUntilDone:NO];
    [self _setProcessing:YES];
    
    BOOL addMovieInfo = [FOPrefs addMovieInfo];
    BOOL addTimestamp = [FOPrefs addTimestamp];
    BOOL addBorder = [FOPrefs addBorder];
    float borderWidth = [FOPrefs borderWidth];
    
    [QTMovie enterQTKitOnThreadDisablingThreadSafetyProtection];
    success &= [_movie waitForLoadState:QTMovieLoadStatePlaythroughOK];
    NSValue* value = [_movie attributeForKey:QTMovieNaturalSizeAttribute];
    NSSize movieSize;
    [value getValue:&movieSize];
    QTTime movieLength = [_movie duration];
    [QTMovie exitQTKitOnThread];
    
    if (!success) {
        error = [NSError errorWithDomain:@"FOScreenGrabber"
                                    code:1
                                userInfo:[NSDictionary dictionaryWithObject:@"Could not open movie file."
                                                                     forKey:NSLocalizedDescriptionKey]];
        goto signalError;
    }
    
    NSSize smallSize;
    smallSize.width = (int)((_imageWidth - (_gridSize.width + 1.0) * borderWidth) / _gridSize.width);
    smallSize.height = (int)((movieSize.height / movieSize.width) * smallSize.width);
    NSSize targetSize = NSMakeSize(_imageWidth, (smallSize.height + borderWidth) * _gridSize.height + borderWidth);
    if (addMovieInfo) {
        targetSize.height += 20.0 * 3.0;
    }
    
    [self _setImage:[[NSImage alloc] initWithSize:targetSize]];
    [_image setFlipped:YES];
    [_image recache];
    
    QTTime timeIncrement = movieLength;
    timeIncrement.timeValue /= _gridSize.width * _gridSize.height;
    QTTime captureTime = timeIncrement;
    if (_gridSize.width == 1 && _gridSize.height == 1) {
	    captureTime.timeValue /= 8;
    } else {
	    captureTime.timeValue /= 2;
    }
    
    unsigned x, y;
    [_image lockFocus];
    [[FOPrefs backgroundColor] set];
    NSRect imageBounds;
    imageBounds.origin = NSZeroPoint;
    imageBounds.size = [_image size];
    [NSBezierPath fillRect:imageBounds];
    
    if (addMovieInfo) {
        [QTMovie enterQTKitOnThreadDisablingThreadSafetyProtection];
        NSAttributedString *info = [self _infoForMovie:_movie];
        [info drawAtPoint:NSMakePoint(8.0 + borderWidth, 4.0)];
        [QTMovie exitQTKitOnThread];
    }
    
    NSMutableDictionary* attr = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 [NSValue valueWithSize:smallSize], QTMovieFrameImageSize, 
                                 [NSNumber numberWithBool:YES], QTMovieFrameImageSessionMode,
                                 nil];
    for (y = 0; y < (int)_gridSize.height; y++) {
        for (x = 0; x < (int)_gridSize.width; x++) {
            [self _setPercentDone:((x + y * _gridSize.width) / (_gridSize.width * _gridSize.height)) * 100.0];
            
            [QTMovie enterQTKitOnThreadDisablingThreadSafetyProtection];
            [_movie setCurrentTime:captureTime];
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                //[_previewMovie setCurrentTime:captureTime];
            });
            
            if (y == ((int)_gridSize.height - 1) && x == ((int)_gridSize.width - 1)) {
                [attr setObject:[NSNumber numberWithBool:NO] forKey:QTMovieFrameImageSessionMode];
            }
            
            NSImage *frame = [_movie frameImageAtTime:captureTime
                                       withAttributes:attr 
                                                error:&error];
            [QTMovie exitQTKitOnThread];
            if (frame == nil) {
                goto signalError;
            }
            
            [frame setFlipped:YES];
            
            NSRect dstRect = NSMakeRect(x * (smallSize.width + borderWidth) + borderWidth, y * (smallSize.height + borderWidth) + borderWidth, smallSize.width, smallSize.height);
            if (addMovieInfo) {
                dstRect.origin.y += 20.0 * 3.0;
            }
            NSRect srcRect = NSMakeRect(0, 0, [frame size].width, [frame size].height); 
            [frame drawInRect:dstRect fromRect:srcRect operation:NSCompositeCopy fraction:1.0];
            if (addBorder) {
                [[[NSColor blackColor] colorWithAlphaComponent:0.5] set];
                [NSBezierPath strokeRect:dstRect];
            }
            if (addTimestamp) {
                NSAttributedString *astime = [self _timestampForTime:captureTime];
                dstRect.origin.x += 3.0;
                dstRect.origin.y += smallSize.height - 15.0;
                [astime drawAtPoint: dstRect.origin];
            }
            [self _setImage:_image];
            captureTime = QTTimeIncrement(captureTime, timeIncrement);
        }
    }
    //NSPoint markPos = NSMakePoint(targetSize.width - 310.0, targetSize.height - 10.0 - 32.0);
    //[[self _waterMark] drawAtPoint:markPos];
    [_image unlockFocus];
    
    [self _setProcessing:NO];
    [_delegate performSelectorOnMainThread:@selector(screenGrabberDidCaptureImages:)
                                withObject:self 
                             waitUntilDone:NO];
    return;
signalError:
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [_delegate screenGrabber:self error:error];
    });
}

@end

@implementation NSObject (FOScreenGrabberDelegate)

- (void)screenGrabberWillCaptureImages:(FOScreenGrabber *)screenGrabber { return; }
- (void)screenGrabberDidCaptureImages:(FOScreenGrabber *)screenGrabber { return; }
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber error:(NSError *)error 
{
    NSLog(@"%@: %@", [screenGrabber className], [error localizedDescription]);
}
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber processingPercentDone:(float)percentDone { return; }
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber processingPartialImage:(NSImage *)image { return; }

@end
