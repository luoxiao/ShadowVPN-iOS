//
//  UDPSocket.h
//  ShadowVPN
//
//  Created by clowwindy on 8/11/15.
//  Copyright © 2015 clowwindy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UDPSocket : NSObject

- (instancetype)initWithIP:(NSString *)ip port:(NSString *)port;
- (void)sendData:(NSData *)data;
- (NSData *)recv;

@end
