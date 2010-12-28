//
//  FOPreviewDocument.h
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
