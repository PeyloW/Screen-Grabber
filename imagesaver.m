//
//  imagesaver.m
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
