//
//  FOScreenGrabber.m
//  ScreenGrabber
//
//  Created by Fredrik Olsson on 2006-08-05.
//  Copyright 2006 Fredrik Olsson. All rights reserved.
//

#import "FOScreenGrabber.h"

#import "FOScreenGrabberPrefs.h"
#import "QTMovieAdditions.h"

@interface FOScreenGrabber (Private)

- (void)_createMovie:(NSMutableArray *)args;

- (void)_setImage:(NSImage *)image;

- (void)_setProcessing:(BOOL)processing;
- (void)_setPercentDone:(float)percentDone;

- (void)_yieldToNumberOfEvents:(uint)count;

// Sort of special, nil if not in thread
- (void)_captureImagesInThread:(NSObject *)inThread;

@end

@implementation FOScreenGrabber

- (id)initWithURL:(NSURL *)url error:(NSError **)error
{
    NSSize size = NSMakeSize((int)[FOPrefs gridSize] / 256, (int)[FOPrefs gridSize] % 256);
    float width = [FOPrefs imageWidth];
    return [self initWithURL:url gridSize:size imageWidth:width error:error];
}


- (id)initWithURL:(NSURL *)url gridSize:(NSSize)gridSize imageWidth:(float)imageWidth error:(NSError **)error;
{
    self = [super init];
    if (self) {
        [self setGridSize:gridSize];
        [self setImageWidth:imageWidth];
        NSMutableArray *args = [NSMutableArray arrayWithObjects:url, [NSValue valueWithPointer:error], nil];
        [self performSelectorOnMainThread:@selector(_createMovie:) withObject:args waitUntilDone:YES];
        error = (NSError **)[[args objectAtIndex:1] pointerValue];
        /*QTMovie *movie = nil;
         if ([args count] == 3) {
         movie = [args objectAtIndex:2];
         AttachMovieToCurrentThread([movie quickTimeMovie]);
         }*/
        QTMovie *movie = [QTMovie movieWithURL:url error:error];
        if (movie) {
            [self setMovie:movie];
        } else {
            self = nil;
        }
    }
    return self;
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

- (QTMovie *)movie
{
    return _movie;
}

- (void)setMovie:(QTMovie *)movie
{
    [self willChangeValueForKey:@"movie"];
    _movie = movie;
    [self didChangeValueForKey:@"movie"];
}

- (NSImage *)image
{
    return _image;
}

- (NSURL *)movieURL
{
    return [_movie attributeForKey:QTMovieURLAttribute];
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

- (unsigned)flatGridSize
{
    NSSize size = [self gridSize];
    return (unsigned)(size.width * 256) + (unsigned)size.height;  
}

- (void)setFlatGridSize:(unsigned)flatGridSize
{
    NSSize size = NSMakeSize(flatGridSize / 256, flatGridSize % 256);
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
    if (_percentDone) {
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
    [self _captureImagesInThread:nil];
}

- (IBAction)captureImagesInThread:(id)sender
{
    [NSThread detachNewThreadSelector:@selector(_captureImagesInThread:) toTarget:self withObject:self];
}

- (IBAction)saveImage:(id)sender
{
    [self _setProcessing:YES];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[_image TIFFRepresentation]];
    NSData *data = nil;
    NSString *path = [[self imageURL] path];
    if ([path hasSuffix:@"png"]) {
        NSDictionary *props = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.2] forKey:NSImageCompressionFactor];
        data = [imageRep representationUsingType:NSPNGFileType properties:props];
    } else if ([path hasSuffix:@"jpg"] || [path hasSuffix:@"jpeg"]) {
        NSDictionary *props = [NSDictionary dictionary];
        data = [imageRep representationUsingType:NSJPEGFileType properties:props];
    }
    if (data) {
        NSError *error = nil;
        NSURL *url = [self imageURL];
        if (![data writeToURL:url options:NSAtomicWrite error:&error]) {
            [_delegate screenGrabber:self error:error];
        }
    } else {
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                              NSLocalizedString(@"ErrorSavingImage", @""), NSLocalizedDescriptionKey,
                              NSLocalizedString(@"ErrorSavingImageDescription", @""), NSLocalizedFailureReasonErrorKey,
                              nil];
        NSError *error = [NSError errorWithDomain:@"FOScreenGrabberDomain" code:1 userInfo:dict];
        [_delegate screenGrabber:self error:error];
    }
    [self _setProcessing:NO];
}

@end

@implementation FOScreenGrabber (Private)

- (void)_createMovie:(NSMutableArray *)args
{
    NSURL *url = [args objectAtIndex:0];
    NSError **error = (NSError **)[[args objectAtIndex:1] pointerValue];
    QTMovie *movie = [QTMovie movieWithURL:url error:error];
    if (movie) {
        //DetachMovieFromCurrentThread([movie quickTimeMovie]);
        [args addObject:movie];
    }
    [args replaceObjectAtIndex:1 withObject:[NSValue valueWithPointer:error]];
}


- (void)_setImage:(NSImage *)image
{
    [self willChangeValueForKey:@"image"];
    if (_image != image) {
        _image = image;
    }
    [self didChangeValueForKey:@"image"];
    if ([self isProcessing]) {
        [_delegate screenGrabber:self processingPartialImage:_image];
    }
}

- (void)_setProcessing:(BOOL)processing
{
    [self willChangeValueForKey:@"processing"];
    if (_isProcessing != processing) {
        [self willChangeValueForKey:@"isIndeterminate"];
        _percentDone = -1.0;
        [self didChangeValueForKey:@"isIndeterminate"];
    }
    _isProcessing = processing;
    [self didChangeValueForKey:@"processing"];
}

- (void)_setPercentDone:(float)percentDone
{
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
}

// Yield to a number of events (if pending).
- (void)_yieldToNumberOfEvents:(uint)count
{
    uint i;
    NSDate *until = nil;
    for (i = 0; i < count; i++) {
        until = [NSDate dateWithTimeIntervalSinceNow:0.01];
        [[NSRunLoop currentRunLoop] runUntilDate:until];
    }
    NSEvent *event;
    until = [NSDate dateWithTimeIntervalSinceNow:0.01];
    while (event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:until inMode:NSEventTrackingRunLoopMode dequeue:YES]) {
        [NSApp sendEvent:event];
    }
}

- (NSAttributedString *)_waterMark
{
    NSString *text = @"ScreenGrabber 2.1";
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    NSFont *font = [NSFont fontWithName:@"Lucida Grande Bold" size:32.0];
    [attrs setObject:font forKey:NSFontAttributeName];
    [attrs setObject:[NSColor colorWithDeviceWhite:0.0 alpha:0.15] forKey:NSForegroundColorAttributeName];
    [attrs setObject:[NSNumber numberWithFloat:-7.0] forKey:NSStrokeWidthAttributeName];
    [attrs setObject:[NSColor colorWithDeviceWhite:1.0 alpha:0.15] forKey:NSStrokeColorAttributeName];
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowOffset:NSMakeSize(3.0, -6.0)];
    [shadow setShadowBlurRadius:3.0];
    [shadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.25]];
    [attrs setObject:shadow forKey:NSShadowAttributeName];
    return [[NSAttributedString alloc] initWithString:text attributes:attrs];
}


- (NSAttributedString *)_infoForMovie:(QTMovie *)movie
{
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
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:text attributes:attrs];
    font = [NSFont fontWithName:@"Lucida Grande Bold" size:16.0];
    [attrs setObject:font forKey:NSFontAttributeName];
    [result setAttributes:attrs range:NSMakeRange(0, [text rangeOfString:@"\n"].location)];
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

#define YIELD(x) {if (!x) { [self _yieldToNumberOfEvents:4]; } }
// Sort of special, nil if not in thread
// But we cannot use this with anything a UI nyway, since QTKit is not threadsafe.
// So in order to not hang the UI we just yield to other events periodically.
- (void)_captureImagesInThread:(NSObject *)inThread
{
    [_delegate screenGrabberWillCaptureImages:self];
    YIELD(inThread);
    [self _setProcessing:YES];
    YIELD(inThread);
    
    BOOL addMovieInfo = [FOPrefs addMovieInfo];
    BOOL addTimestamp = [FOPrefs addTimestamp];
    BOOL addBorder = [FOPrefs addBorder];
    float borderWidth = [FOPrefs borderWidth];
    
    NSSize movieSize = [[_movie currentFrameImage] size];
    NSSize smallSize;
    smallSize.width = (_imageWidth - (_gridSize.width + 1.0) * borderWidth) / _gridSize.width;
    smallSize.height = (movieSize.height / movieSize.width) * smallSize.width;
    NSSize targetSize = NSMakeSize(_imageWidth, (smallSize.height + borderWidth) * _gridSize.height + borderWidth);
    if (addMovieInfo) {
        targetSize.height += 20.0 * 3.0;
    }
    
    [self _setImage:[[NSImage alloc] initWithSize:targetSize]];
    [_image setFlipped:YES];
    [_image recache];
    YIELD(inThread);
    
    QTTime moviewLength = [_movie duration];
    QTTime timeIncrement = moviewLength;
    timeIncrement.timeValue /= _gridSize.width * _gridSize.height;
    QTTime captureTime = timeIncrement;
    captureTime.timeValue /= 2;
    
    [self _setPercentDone:0.0];
    YIELD(inThread);
    
    unsigned x, y;
    [_image lockFocus];
    [[FOPrefs backgroundColor] set];
    NSRect imageBounds;
    imageBounds.origin = NSZeroPoint;
    imageBounds.size = [_image size];
    [NSBezierPath fillRect:imageBounds];
    
    if (addMovieInfo) {
        NSAttributedString *info = [self _infoForMovie:_movie];
        [info drawAtPoint:NSMakePoint(8.0 + borderWidth, 4.0)];
    }
    
    for (y = 0; y < (int)_gridSize.height; y++) {
        for (x = 0; x < (int)_gridSize.width; x++) {
            [_movie setCurrentTime:captureTime];
            
            [self _setPercentDone:((x + y * _gridSize.width) / (_gridSize.width * _gridSize.height)) * 100.0];
            YIELD(inThread);
            
            NSImage *frame = [_movie imageAtTime:captureTime];
            
            [frame setFlipped:YES];
            
            /*
             NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[frame TIFFRepresentation]];
             NSDictionary *props = [NSDictionary dictionary];
             NSData *data = [imageRep representationUsingType:NSJPEGFileType properties:props];
             NSString *path = [NSString stringWithFormat:@"~/Desktop/%@.jpg", QTStringFromTime(captureTime), nil];
             NSURL *url = [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]];
             [data writeToURL:url options:NSAtomicWrite error:NULL];
             */
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
            YIELD(inThread);
            captureTime = QTTimeIncrement(captureTime, timeIncrement);
        }
    }
    NSPoint markPos = NSMakePoint(targetSize.width - 310.0, targetSize.height - 10.0 - 32.0);
    [[self _waterMark] drawAtPoint:markPos];
    [_image unlockFocus];
    
    [self _setProcessing:NO];
    YIELD(inThread);
    [_delegate screenGrabberDidCaptureImages:self];
    YIELD(inThread);
    if (inThread) {
        [NSThread exit];
    }
}

@end

@implementation NSObject (FOScreenGrabberDelegate)

- (void)screenGrabberWillCaptureImages:(FOScreenGrabber *)screenGrabber { return; }
- (void)screenGrabberDidCaptureImages:(FOScreenGrabber *)screenGrabber { return; }
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber error:(NSError *)error 
{
    NSLog(@"%@: %@", [screenGrabber className], [error localizedDescription], nil);
}
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber processingPercentDone:(float)percentDone { return; }
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber processingPartialImage:(NSImage *)image { return; }

@end
