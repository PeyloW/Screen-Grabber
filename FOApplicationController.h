/* FOApplicationController */

#import <Cocoa/Cocoa.h>

#import "FOBatchScreenGrabber.h"

@interface FOApplicationController : NSObject
{
@private
    NSPanel *batchProcessingPanel;
    FOBatchScreenGrabber *batchScreenGrabber;
}

- (IBAction)batchProcessMovies:(id)sender;
- (IBAction)toggleBatchProcessingPanel:(id)sender;

@end

