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

- (void)applicationWillTerminate:(NSNotification *)notification;

@end


@implementation FOApplicationController

- (IBAction)batchProcessMovies:(id)sender
{
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:YES];
    [panel beginWithCompletionHandler:^(NSInteger result) 
    {
        if (result == NSOKButton) {
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
    }];
}

- (IBAction)toggleBatchProcessingPanel:(id)sender
{
    if ([NSThread isMainThread]) {
        if ([batchProcessingPanel isVisible]) {
            [batchProcessingPanel orderOut:sender];
        } else {
            [batchProcessingPanel makeKeyAndOrderFront:sender];
        }
    } else {
        [self performSelectorOnMainThread:_cmd withObject:sender waitUntilDone:YES];
    }
}

@end



@implementation FOApplicationController (Private)

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] synchronize];
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
