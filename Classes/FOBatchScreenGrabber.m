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
#include <pwd.h>

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
            result = [_urls copy];
        } else {
            result = [NSArray array];
        }
    }
    return result;
}

- (NSArray *)pendingFiles
{
    if (_urls) {
        NSMutableArray *files = [_urls mutableCopy];
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

-(void)_processMoviesToURL:(NSURL*)baseURL;
{
    //NSURL* baseURL = [NSURL fileURLWithPath:[@"~/Pictures" stringByExpandingTildeInPath]];
    while (1) {
        @autoreleasepool {
            NSURL *nextURL = nil;
            [self willChangeValueForKey:@"pendingFiles"];
            [self willChangeValueForKey:@"pendingURLs"];
            @synchronized(_urls) {
                if ([_urls count] > 0) {
                    nextURL = [_urls objectAtIndex:0];
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
                        NSString* name = [[screenGrabber imageURL] lastPathComponent];
                        NSURL* imageURL = [baseURL URLByAppendingPathComponent:name];                    
                        [screenGrabber setImageURL:imageURL];
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
            } else {
                break;
            }
        }
    }
    @autoreleasepool {
        [self willChangeValueForKey:@"isProcessing"];
        @synchronized(self) {
            _runningThreads--;
        }
        [self didChangeValueForKey:@"isProcessing"];
        [[NSWorkspace sharedWorkspace] performSelectorOnMainThread:@selector(openURL:) withObject:baseURL waitUntilDone:NO];
        //[NSThread exit];
    }
}


// Process movies on this thread until there is no more to fetch!
- (void)_processMovies
{
    if (_saveToURL) {
        [self _processMoviesToURL:_saveToURL];
    } else {
        @autoreleasepool {
            //NSURL* baseURL = [[NSFileManager defaultManager] URLForDirectory:NSPicturesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
            struct passwd pd;
            struct passwd* pwdptr=&pd;
            struct passwd* tempPwdPtr;
            char pwdbuffer[200];
            int  pwdlinelen = sizeof(pwdbuffer);
            NSURL* baseURL = nil;
            if ((getpwuid_r(getuid(),pwdptr,pwdbuffer,pwdlinelen,&tempPwdPtr))==0) {
                baseURL = [[NSURL fileURLWithPath:[NSString stringWithCString:pd.pw_dir encoding:NSUTF8StringEncoding]] URLByAppendingPathComponent:@"Pictures"];
                printf("The initial directory is:    %s\n", pd.pw_dir);
            }
            NSOpenPanel* openPanel = [NSOpenPanel openPanel];
            [openPanel setCanChooseFiles:NO];
            [openPanel setCanChooseDirectories:YES];
            [openPanel setDirectoryURL:baseURL];
            [openPanel setTitle:@"Choose Output Directory"];
            [openPanel setMessage:@"One image for each batch processed movie will be saved to the output directory."];
            [openPanel setPrompt:@"Choose"];
            [openPanel beginWithCompletionHandler:^(NSInteger result) {
                if (result == NSFileHandlingPanelOKButton) {
                    _saveToURL = [[openPanel URL] copy];
                    [self startBatchWithThreads:1];
                }
            }];
        }
    }
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
