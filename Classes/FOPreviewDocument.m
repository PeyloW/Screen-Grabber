//
//  FOPreviewDocument.m
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

#import "FOPreviewDocument.h"


@interface FOPreviewDocument (Private)

- (NSString *)windowNibName;
- (void)windowControllerDidLoadNib:(NSWindowController *)windowController;

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)error;
- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)error;

- (void)screenGrabberWillCaptureImages:(FOScreenGrabber *)screenGrabber;
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber processingPercentDone:(float)percentDone;
- (void)screenGrabberDidCaptureImages:(FOScreenGrabber *)screenGrabber;
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber error:(NSError *)error;

@end



@implementation FOPreviewDocument

- (FOScreenGrabber *)screenGrabber
{
    return _screenGrabber;
}

- (IBAction)captureImages:(id)sender;
{
    [_screenGrabber captureImages:sender];
}


- (IBAction)captureImagesAs:(id)sender;
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"jpeg", @"png", nil]];
    [panel setCanCreateDirectories:YES];
    [panel setCanSelectHiddenExtension:YES];
    NSString *dir = [[[_screenGrabber imageURL] path] stringByDeletingLastPathComponent];
    NSString *name = [[[_screenGrabber imageURL] path] lastPathComponent];
    [panel setDirectoryURL:[NSURL fileURLWithPath:dir isDirectory:YES]];
    [panel setNameFieldStringValue:name];
    [panel beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger result) {
        [panel orderOut:self];
        if (result == NSOKButton) {
            [_screenGrabber setImageURL:[panel URL]];
            [_screenGrabber captureImages:self];
        }
    }];
}

@end



@implementation FOPreviewDocument (Private)

- (NSString *)windowNibName
{
    return @"PreviewDocument";
}

- (NSSize)windowWillResize:(NSWindow *)window toSize:(NSSize)frameSize;
{
    NSSize size = [[[self screenGrabber] movie] naturalSize];
    frameSize.height = (int)(frameSize.width * (size.height / size.width));
    frameSize.height += 66;
    NSLog(@"Window size: %@", NSStringFromSize(frameSize));
    return frameSize;
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController
{
    [progressIndicator setUsesThreadedAnimation:YES];
    NSRect frame = [mainWindow frame];
    frame.size = [self windowWillResize:mainWindow toSize:frame.size];
    [mainWindow setFrame:frame display:YES];
    [[text1 cell] setBackgroundStyle:NSBackgroundStyleRaised];
    [[text2 cell] setBackgroundStyle:NSBackgroundStyleRaised];
    [[text3 cell] setBackgroundStyle:NSBackgroundStyleRaised];
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)error
{
    [self willChangeValueForKey:@"screenGrabber"];
    _screenGrabber = [[FOScreenGrabber alloc] initWithURL:url error:error];
    if (_screenGrabber) {
        [_screenGrabber setDelegate:self];
    }
    [self didChangeValueForKey:@"screenGrabber"];
    return _screenGrabber != nil;
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)error
{
    [_screenGrabber setImageURL:url];
    // Stupid QTKit is not threadsafe...
    [_screenGrabber captureImagesInThread:nil];
    return YES;
}

- (void)screenGrabberWillCaptureImages:(FOScreenGrabber *)screenGrabber
{
    [NSApp beginSheet:progressSheet modalForWindow:mainWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];
}

- (void)screenGrabber:(FOScreenGrabber *)screenGrabber processingPercentDone:(float)percentDone
{
    [progressIndicator setDoubleValue:percentDone];
}

- (void)screenGrabberDidCaptureImages:(FOScreenGrabber *)screenGrabber 
{
    [screenGrabber saveImage:self];
    [NSApp endSheet:progressSheet];
    [progressSheet orderOut:self];
}

- (void)screenGrabber:(FOScreenGrabber *)screenGrabber error:(NSError *)error
{ 
    NSAlert *alert = [NSAlert alertWithError:error];
    [NSApp endSheet:progressSheet];
    [progressSheet orderOut:self];
    [alert beginSheetModalForWindow:mainWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox;
{
    if ([aComboBox tag] == 1) {
		return 13;
    } else if ([aComboBox tag] == 2) {
    	return 12;
	}
	return 0;
}

-(id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index;
{
    if ([aComboBox tag] == 1) {
        static int widths[13] = (int[]){320, 480, 640, 800, 960, 1024, 1280, 1440, 1600, 1920, 2048, 2560, 4096 };
        return [NSNumber numberWithFloat:widths[index]];
    }
    if ([aComboBox tag] == 2) {
        static int widths[12] = (int[]){1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 24, 32 };
        return [NSNumber numberWithFloat:widths[index]];
    }
    return nil;
}

@end
