//
//  FOBatchScreenGrabber.h
//  ScreenGrabber
//
//  Created by Fredrik Olsson on 2006-08-12.
//  Copyright 2006 Fredrik Olsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FOBatchScreenGrabber : NSObject 
{
@private
    NSMutableArray *_urls;
    NSURL *_currentURL;
    uint _runningThreads;
    id _delegate;
}

// Initialize and return a batch screen grabber with a set of URLs to process.
- (id)initWithURLs:(NSArray *)urls;

// Return the recievers delegate.
- (id)delegate;
// Set the recievers delegate.
- (void)setDelegate:(id)delegate;

// Add URLs to the recievers batch que.
- (void)addURLs:(NSArray *)urls;

// Returns an array with URLs pending batch processing.
// URLs currently being processed are not in pending.
- (NSArray *)pendingURLs;
- (NSArray *)pendingFiles;

// Returns a string with the name of the currently processed file.
// This violates the multithreading plan a bit :/
- (NSURL *)currentURL;
- (NSString *)currentFile;

// Returns a boolean indicating if batch processing is currently being done.
- (BOOL)isProcessing;

// Begin processing of URLs in pending que using specified number of threads.
// Two threads should be OK as most Apple machines have dual processors or at
// least dual cores.
- (void)startBatchWithThreads:(uint)count;


@end


@interface NSObject (FOBatchScreenGrabberDelegate)

// This delegate gives us the option to filter URLs, and assign specific delages to each FOScreenGrabber job.
// By default all URLs are accepted.
- (BOOL)batchScreenGrabber:(FOBatchScreenGrabber *)batchScreenGrabber shouldProcessURL:(NSURL *)url withDelegate:(id*)delegate;

// Time to update UI maybe.
- (void)batchScreenGrabber:(FOBatchScreenGrabber *)batchScreenGrabber willProcessURL:(NSURL *)url;

// Ditto
- (void)batchScreenGrabber:(FOBatchScreenGrabber *)batchScreenGrabber didProcessURL:(NSURL *)url;

// This delegate allows us to present errors to users, and optionaly continue the batch anyway.
// By default errors are written to the system log, and job continues.
// There is nothing wrong with adding the URL into the batch que again, unless infinite loop is a broblem.
- (BOOL)batchScreenGrabber:(FOBatchScreenGrabber *)batchScreenGrabber shouldStopProcessingWithError:(NSError *)error; 

@end