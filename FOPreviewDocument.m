//
//  FOPreviewDocument.m
//  ScreenGrabber
//
//  Created by Fredrik Olsson on 2006-08-05.
//  Copyright Fredrik Olsson 2006 . All rights reserved.
//

#import "FOPreviewDocument.h"


@interface FOPreviewDocument (Private)

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

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
    [panel beginSheetForDirectory:dir file:name modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}


@end



@implementation FOPreviewDocument (Private)

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
    if (returnCode == NSOKButton) {
        [_screenGrabber setImageURL:[sheet URL]];
        [_screenGrabber captureImages:self];
    }
}


- (NSString *)windowNibName
{
    return @"PreviewDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController
{
    [progressIndicator setUsesThreadedAnimation:YES];
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
    [alert runModal];
}

@end
