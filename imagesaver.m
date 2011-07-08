//
//  main.c
//  imagesaver
//
//  Created by Fredrik Olsson on 2011-07-08.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include <xpc/xpc.h>
#include <assert.h>
#include <Foundation/Foundation.h>

static void imagesaver_peer_event_handler(xpc_connection_t peer, xpc_object_t event) 
{
    if (xpc_get_type(event) == XPC_TYPE_DICTIONARY) {
        xpc_connection_t remote = xpc_dictionary_get_remote_connection(event);
        xpc_object_t reply = xpc_dictionary_create_reply(event);

        NSString* urlString = [NSString stringWithUTF8String:xpc_dictionary_get_string(event, "url")];
        NSURL* url = [NSURL URLWithString:urlString];
        NSLog(@"url: %@", url);
        
        
        xpc_object_t shmem = xpc_dictionary_get_value(event, "data");
        void* sharedMem = NULL;
        size_t dataLen = xpc_shmem_map(shmem, &sharedMem);
        NSData* data = [NSData dataWithBytes:sharedMem length:dataLen];
        NSLog(@"data: %d bytes", [data length]);
        
        NSError* error = nil;
        BOOL success = [data writeToURL:url options:NSAtomicWrite error:&error];

        xpc_dictionary_set_bool(reply, "success", success);
        if (error) {
            NSData* data = [NSKeyedArchiver archivedDataWithRootObject:error];
            xpc_dictionary_set_data(reply, "error", [data bytes], [data length]);
        }
        xpc_connection_send_message(remote, reply);
        xpc_release(reply);
    } else {
        // Errors we haz them.
        xpc_release(peer);
	}
}

static void imagesaver_event_handler(xpc_connection_t peer) 
{
	xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
		imagesaver_peer_event_handler(peer, event);
	});
	xpc_connection_resume(peer);
}

int main(int argc, const char *argv[])
{
	xpc_main(imagesaver_event_handler);
	return 0;
}
