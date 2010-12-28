//
//  FOPreviewDocument.h
//  ScreenGrabber
//
//  Created by Fredrik Olsson on 2006-08-05.
//  Copyright Fredrik Olsson 2006 . All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "FOScreenGrabber.h"

@interface FOPreviewDocument : NSDocument
{
@protected
    NSWindow *mainWindow;
    NSWindow *progressSheet;
    QTMovieView *movieView;
    NSProgressIndicator *progressIndicator;
@private 
    FOScreenGrabber *_screenGrabber;
}

- (FOScreenGrabber *)screenGrabber;

- (IBAction)captureImages:(id)sender;
- (IBAction)captureImagesAs:(id)sender;

@end
