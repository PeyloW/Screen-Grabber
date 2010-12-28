//
//  QTMovieAdditions.h
//  ScreenGrabber
//
//  Created by Fredrik Olsson on 2006-08-15.
//  Copyright 2006 Fredrik Olsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <QTKit/QTKit.h>

@interface QTMovie (Additions)

- (NSString *)movieName;
- (NSString *)movieDuration;

- (BOOL)haveMPEGTrack;
- (BOOL)haveVideoTrack;
- (BOOL)haveAudioTrack;

- (NSString *)videoResolution;
- (NSString *)videoKbps;
- (NSString *)videoCodec;

- (NSString *)audioFrequenzy;
- (NSString *)audioKbps;
- (NSString *)audioCodec;

- (NSImage *)imageAtTime:(QTTime)qttime;

@end
