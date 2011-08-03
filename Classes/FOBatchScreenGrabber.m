//
//  FOBatchScreenGrabber.m
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

#import "FOBatchScreenGrabber.h"

#import "FOScreenGrabber.h"

@interface FOBatchScreenGrabber (Private)

- (void)_setCurrentURL:(NSURL *)url;

- (void)_processMovies;

@end


@implementation FOBatchScreenGrabber

- (id)initWithURLs:(NSArray *)urls
{
    self = [super init];
    if (self) {
        [self addURLs:urls];
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

- (void)addURLs:(NSArray *)urls
{
    [self willChangeValueForKey:@"pendingFiles"];
    [self willChangeValueForKey:@"pendingURLs"];
    @synchronized(self) {
        if (_urls) {
            [_urls addObjectsFromArray:urls];
        } else {
            _urls = [urls mutableCopy];
        }
    }
    [self didChangeValueForKey:@"pendingURLs"];
    [self didChangeValueForKey:@"pendingFiles"];
}

- (NSArray *)pendingURLs
{
    NSArray *result = nil;
    @synchronized(self) {
        if (_urls) {
            result = [[_urls copy] autorelease];
        } else {
            result = [NSArray array];
        }
    }
    return result;
}

- (NSArray *)pendingFiles
{
    if (_urls) {
        NSMutableArray *files = [[_urls mutableCopy] autorelease];
        uint i, count = [files count];
        for (i = 0; i < count; i++) {
            NSString *file = [[[files objectAtIndex:i] path] lastPathComponent];
            [files replaceObjectAtIndex:i withObject:file];
        }
        return files;
    }
    return nil;
}

- (NSURL *)currentURL
{
    return _currentURL;
}

- (NSString *)currentFile
{
    if (_currentURL) {
        return [[_currentURL path] lastPathComponent];
    }
    return nil;
}

- (BOOL)isProcessing
{
    BOOL result = NO;
    @synchronized(self) {
        result = _runningThreads > 0;
    }
    return result;
}

- (void)startBatchWithThreads:(uint)count
{
    uint index;
    for (index = 0; index < count; index++) {
        [self willChangeValueForKey:@"isProcessing"];
        @synchronized(self) {
            _runningThreads++;
            //[NSThread detachNewThreadSelector:@selector(_processMovies) toTarget:self withObject:nil];
            [self performSelectorInBackground:@selector(_processMovies) withObject:nil];
        }
        [self didChangeValueForKey:@"isProcessing"];
    }
}

@end

@implementation FOBatchScreenGrabber (Private)

- (void)_setCurrentURL:(NSURL *)url
{
    [self willChangeValueForKey:@"currentFile"];
    [self willChangeValueForKey:@"currentURL"];
    _currentURL = [url copy];
    [self didChangeValueForKey:@"currentURL"];
    [self didChangeValueForKey:@"currentFile"];
    
}


// Process movies on this thread until there is no more to fetch!
- (void)_processMovies
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    while (1) {
        NSURL *nextURL = nil;
        [self willChangeValueForKey:@"pendingFiles"];
        [self willChangeValueForKey:@"pendingURLs"];
        @synchronized(_urls) {
            if ([_urls count] > 0) {
                nextURL = [[_urls objectAtIndex:0] retain];
                [_urls removeObject:nextURL];
            }
        }
        [self didChangeValueForKey:@"pendingURLs"];
        [self didChangeValueForKey:@"pendingFiles"];    
        if (nextURL) {
            id delegate = nil;
            BOOL shouldProcess = YES;
            if (_delegate) {
                shouldProcess = [_delegate batchScreenGrabber:self shouldProcessURL:nextURL withDelegate:&delegate];
            }
            if (shouldProcess) {
                [_delegate batchScreenGrabber:self willProcessURL:nextURL];
                NSError *error;
                [self _setCurrentURL:nextURL];
                FOScreenGrabber *screenGrabber = [[FOScreenGrabber alloc] initWithURL:nextURL error:&error];
                if (screenGrabber) {
                    [screenGrabber setDelegate:delegate];
                    [screenGrabber captureImages:self]; // This could fail...
                    [screenGrabber saveImage:self];     // And this could fail...
                    [_delegate batchScreenGrabber:self didProcessURL:nextURL];
                } else {
                    BOOL shouldStop = NO;
                    if (_delegate) {
                        shouldStop = [_delegate batchScreenGrabber:self shouldStopProcessingWithError:error];
                    }
                    if (shouldStop) {
                        [self _setCurrentURL:nil];
                        break;
                    }
                }
            }
            [self _setCurrentURL:nil];
            [nextURL release];
        } else {
            break;
        }
    }
    [self willChangeValueForKey:@"isProcessing"];
    @synchronized(self) {
        _runningThreads--;
    }
    [self didChangeValueForKey:@"isProcessing"];
    [pool release];
    //[NSThread exit];
}

@end

@implementation NSObject (FOBatchScreenGrabberDelegate)

- (BOOL)batchScreenGrabber:(FOBatchScreenGrabber *)batchScreenGrabber shouldProcessURL:(NSURL *)url withDelegate:(id*)delegate { return YES; }
- (void)batchScreenGrabber:(FOBatchScreenGrabber *)batchScreenGrabber willProcessURL:(NSURL *)url { return; }
- (void)batchScreenGrabber:(FOBatchScreenGrabber *)batchScreenGrabber didProcessURL:(NSURL *)url { return; }
- (BOOL)batchScreenGrabber:(FOBatchScreenGrabber *)batchScreenGrabber shouldStopProcessingWithError:(NSError *)error
{
    NSLog(@"%@: %@", [batchScreenGrabber className], [error localizedDescription]);
    return NO;
}

@end
