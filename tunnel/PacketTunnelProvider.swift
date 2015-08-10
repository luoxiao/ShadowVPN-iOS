//
//  PacketTunnelProvider.swift
//  tunnel
//
//  Created by clowwindy on 7/18/15.
//  Copyright © 2015 clowwindy. All rights reserved.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    var conf = [String: AnyObject]()
    var pendingStartCompletion: (NSError? -> Void)?
    var userToken: NSData?
    var chinaDNS: ChinaDNSRunner?
    var routeManager: RouteManager?
    var queue: dispatch_queue_t?
    var socket: UDPSocket?
    
    override func startTunnelWithOptions(options: [String : NSObject]?, completionHandler: (NSError?) -> Void) {
        queue = dispatch_queue_create("shadowvpn.vpn", DISPATCH_QUEUE_SERIAL)
        conf = (self.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!
        self.pendingStartCompletion = completionHandler
        chinaDNS = ChinaDNSRunner(DNS: conf["dns"] as? String)
        if let userTokenString = conf["usertoken"] as? String {
            if userTokenString.characters.count == 16 {
                userToken = NSData.fromHexString(userTokenString)
            }
        }
        self.createUDP()
        self.updateNetwork()
    }
    
    func createUDP() {
        self.socket = UDPSocket(IP: conf["server"] as! String, port: conf["port"] as! String)
        dispatch_async(queue!) { () -> Void in
            while true {
                NSLog("UDP queue while")
                if let data = self.socket?.recv() {
                    NSLog("UDP: %d", data.length)
                    let decrypted = SVCrypto.decryptWithData(data, userToken: self.userToken)
                    self.packetFlow.writePackets([decrypted], withProtocols: [2])
                } else {
                    sleep(1)
                }
            }
        }
    }
    
    func updateNetwork() {
        NSLog("updateNetwork")
        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: self.protocolConfiguration.serverAddress!)
        newSettings.IPv4Settings = NEIPv4Settings(addresses: [conf["ip"] as! String], subnetMasks: [conf["subnet"] as! String])
        routeManager = RouteManager(route: conf["route"] as? String, IPv4Settings: newSettings.IPv4Settings!)
        if conf["mtu"] != nil {
            newSettings.MTU = Int(conf["mtu"] as! String)
        } else {
            newSettings.MTU = 1432
        }
        if "chnroutes" == (conf["route"] as? String) {
            NSLog("using ChinaDNS")
            newSettings.DNSSettings = NEDNSSettings(servers: ["127.0.0.1"])
        } else {
            NSLog("using DNS")
            newSettings.DNSSettings = NEDNSSettings(servers: (conf["dns"] as! String).componentsSeparatedByString(","))
        }
        // add server ip to exclude list
        newSettings.IPv4Settings?.excludedRoutes?.append(NEIPv4Route(destinationAddress: conf["server"] as! String, subnetMask: "255.255.255.255"))
        
        NSLog("setPassword")
        SVCrypto.setPassword(conf["password"] as! String)
        NSLog("setTunnelNetworkSettings")
        self.setTunnelNetworkSettings(newSettings) { (error: NSError?) -> Void in
            NSLog("readPacketsFromTUN")
            self.readPacketsFromTUN()
            if let completionHandler = self.pendingStartCompletion {
                // send an packet
                //        self.log("completion")
                NSLog("%@", String(error))
                NSLog("VPN started")
                completionHandler(error)
                if error != nil {
                    // simply kill the extension process
                    exit(0)
                }
            }
        }
    }
    
    func readPacketsFromTUN() {
        self.packetFlow.readPacketsWithCompletionHandler {
            packets, protocols in
            for packet in packets {
                NSLog("TUN: %d", packet.length)
                self.socket?.sendData(SVCrypto.encryptWithData(packet, userToken: self.userToken))
            }
            self.readPacketsFromTUN()
        }
        
    }
    
    override func stopTunnelWithReason(reason: NEProviderStopReason, completionHandler: () -> Void) {
        // Add code here to start the process of stopping the tunnel
        NSLog("stopTunnelWithReason")
        completionHandler()
        super.stopTunnelWithReason(reason, completionHandler: completionHandler)
        // simply kill the extension process
        exit(0)
    }
    
    override func handleAppMessage(messageData: NSData, completionHandler: ((NSData?) -> Void)?) {
        // Add code here to handle the message
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleepWithCompletionHandler(completionHandler: () -> Void) {
        // Add code here to get ready to sleep
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up
    }
}
