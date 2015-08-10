//
//  UDPSocket.m
//  ShadowVPN
//
//  Created by clowwindy on 8/11/15.
//  Copyright © 2015 clowwindy. All rights reserved.
//

#import "UDPSocket.h"

#include <fcntl.h>
#include <netdb.h>
#include <resolv.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <arpa/inet.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/time.h>


@implementation UDPSocket {
    int fd;
    struct addrinfo *addr_ip;
    char buf[2048];
}

- (instancetype)initWithIP:(NSString *)ip port:(NSString *)port {
    self = [super init];
    if (self) {
        fd = 0;
        [self recreateSocket];
        
        struct addrinfo hints;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_INET;
        hints.ai_socktype = SOCK_DGRAM;
        if (0 != getaddrinfo([ip dataUsingEncoding:NSUTF8StringEncoding].bytes, [port dataUsingEncoding:NSUTF8StringEncoding].bytes, &hints, &addr_ip)) {
            return nil;
        }
    }
    return self;
}

- (void)sendData:(NSData *)data {
    ssize_t r = sendto(fd, data.bytes, data.length, 0, addr_ip->ai_addr, addr_ip->ai_addrlen);
    if (r < 0) {
        NSLog(@"%s", strerror(errno));
    }
}

- (void)recreateSocket {
    NSLog(@"recreateSocket");
    if (fd != 0) {
        close(fd);
    }
    fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd <= 0) {
        NSLog(@"%s", strerror(errno));
    }
}

- (NSData *)recv {
    ssize_t r = recvfrom(fd, buf, sizeof(buf), 0, NULL, NULL);
    if (r > 0) {
        return [NSData dataWithBytes:buf length:r];
    } else {
        NSLog(@"%s", strerror(errno));
    }
    return nil;
}

@end
