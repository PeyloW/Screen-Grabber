//
//  FOApplicationController.h
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

#import "FOApplicationController.h"

#import "FOScreenGrabberPrefs.h"


@interface FOApplicationController (Private)

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

- (void)applicationWillTerminate:(NSNotification *)notification;


@end


@implementation FOApplicationController

- (IBAction)batchProcessMovies:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:YES];
    NSArray *types = [NSArray arrayWithObjects:@"mpg", @"avi", @"mpeg", @"mov", @"wmv", nil];
    [openPanel beginForDirectory:nil file:nil types:types modelessDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (IBAction)toggleBatchProcessingPanel:(id)sender
{
    if ([batchProcessingPanel isVisible]) {
        [batchProcessingPanel orderOut:sender];
    } else {
        [batchProcessingPanel makeKeyAndOrderFront:sender];
    }
}

@end



@implementation FOApplicationController (Private)

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    if (returnCode == NSOKButton) {
        [batchProcessingPanel orderFront:self];
        NSArray *originalURLs = [panel URLs];
        NSMutableArray *urls = [NSMutableArray arrayWithCapacity:[originalURLs count]];
        NSFileManager *manager = [NSFileManager defaultManager];
        NSURL *url = nil;
        for (url in originalURLs) {
            BOOL isDir = NO;
            if ([manager fileExistsAtPath:[url path] isDirectory:&isDir]) {
                if (isDir) {
                    NSString *path = [url path];
                    NSDirectoryEnumerator *dirEnum = [manager enumeratorAtPath:path];
                    NSString *file = nil;
                    while (file = [dirEnum nextObject]) {
                        [urls addObject:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:file]]];
                    }
                } else {
                    [urls addObject:url];
                }
            }
        }
        if (batchScreenGrabber) {
            [batchScreenGrabber addURLs:urls];
        } else {
            [self willChangeValueForKey:@"batchScreenGrabber"];
            batchScreenGrabber = [[FOBatchScreenGrabber alloc] initWithURLs:urls];
            [self didChangeValueForKey:@"batchScreenGrabber"];
        }
        if (![batchScreenGrabber isProcessing]) {
            [batchScreenGrabber startBatchWithThreads:1];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
}

@end
