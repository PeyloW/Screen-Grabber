//
//  FOScreenGrabber.h
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
#import <QTKit/QTKit.h>

@interface FOScreenGrabber : NSObject 
{
@private
    id _delegate;
    QTMovie *_movie;
    NSImage *_image;
    NSSize _gridSize;
    float _imageWidth;
    BOOL _isProcessing;
    float _percentDone;
    NSURL *_imageURL;
}

// Initialize and return a screen grabber for given URL with all user default options.
- (id)initWithURL:(NSURL *)url error:(NSError **)error;

// Initialize and return a screen grabber for given URL, with specified image and grid size.
// All other options are fetched from user defaults.
- (id)initWithURL:(NSURL *)url gridSize:(NSSize)gridSize imageWidth:(float)imageWidth error:(NSError **)error;

// Returns the recievers delegate.
- (id)delegate;
// Set the recievers delegate.
- (void)setDelegate:(id)delegate;

// Returns the movie object assiciated with the reciever.
- (QTMovie *)movie;

// Set the movie object associated with the reciever.
// This should never be needed to call directly.
- (void)setMovie:(QTMovie *)movie;

// Returns the grabbed image of the reciever, or nil of none exist yet.
- (NSImage *)image;

// Returns the URL for the movie object associated witht the reciever.
- (NSURL *)movieURL;

// Returns the URL for the target image associated with the reciever.
// By default the save as movieURL with the image's file extension appended.
- (NSURL *)imageURL;

// Set the URL for the recievers associated image.
- (void)setImageURL:(NSURL *)url;

// Returns the recievers image grid size.
- (NSSize)gridSize;

// Sets the recievers image grid size.
// This does not change the user default.
- (void)setGridSize:(NSSize)gridSize;

// Returns the recievers images grid size as an ineteger value.
// The grid size is x * 256 + y, and suitable for UI tags.
- (unsigned)flatGridSize;

// Sets the recievers image grid size.
- (void)setFlatGridSize:(unsigned)flatGridSize;

// Returns the recievers image width.
- (float)imageWidth;

// Sets the recievers image grid size.
- (void)setImageWidth:(float)imageWidth;

// Returns a boolean indicating if the reciever is currebtly processing.
- (BOOL)isProcessing;

// Returns percentage as a float of how far the reciever is done processing.
- (float)percentDone;

// Returns a boolean indicating if it can be determinated how far the reciever is done processing. 
- (BOOL)isIndeterminate;

// Capture images in current thread.
// Method returns when done.
- (IBAction)captureImages:(id)sender;

// Capture images in seperate thread.
// Method return imidiately.
// Be warned that QTKit is not thread safe and can thus not display movie in UI while processing.
- (IBAction)captureImagesInThread:(id)sender;

// Save captured image.
- (IBAction)saveImage:(id)sender;

@end



@interface NSObject (FOScreenGrabberDelegate)

// Screen capture processing will start.
- (void)screenGrabberWillCaptureImages:(FOScreenGrabber *)screenGrabber;

// Screen capture processing did end sucessfully.
- (void)screenGrabberDidCaptureImages:(FOScreenGrabber *)screenGrabber;

// Screen capture processing or other operation failed with an error.
// The error is useful for informing the user.
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber error:(NSError *)error;

// Delegate method for updating UI. For some reason bindings and NSProgressINdicator does not work as expected?
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber processingPercentDone:(float)percentDone;

// Delegate method for informing that a new partial image can be fetched.
- (void)screenGrabber:(FOScreenGrabber *)screenGrabber processingPartialImage:(NSImage *)image;

@end
