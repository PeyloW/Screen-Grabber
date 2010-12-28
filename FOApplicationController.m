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
        NSEnumerator *urlsEnum = [originalURLs objectEnumerator];
        NSURL *url = nil;
        while (url = [urlsEnum nextObject]) {
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
