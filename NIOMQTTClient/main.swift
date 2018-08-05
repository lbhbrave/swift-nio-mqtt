//
//  main.swift
//  NIOMQTTClient
//
//  Created by yh on 2018/8/4.
//
import NIO
import MQTTDecoder
import Dispatch

/// `Dispatch` executed the submitted block.
final class MQTTServerHandler: ChannelInboundHandler {
    
    public typealias InboundIn = MQTTPacket
    public typealias OutboundOut = MQTTPacket
    
    let maxGrantedQosLevel: UInt8 = 0
    
    struct subscribtion {
        let channel: Channel
        let qos: MQTTQos
    }
    
    // All access to channels is guarded by channelsSyncQueue.
    private let channelsSyncQueue = DispatchQueue(label: "channelsQueue")
    
    private var clients: [ObjectIdentifier: Channel] = [:]
    private var subscribtions: [String: [subscribtion]] = [:]
    //
    public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let id = ObjectIdentifier(ctx.channel)
        let packet = self.unwrapInboundIn(data)
        clients[id] = ctx.channel
        do {
            switch packet {
            case .CONNEC(let packet):
                try handleConnection(packet: packet, ctx: ctx)
            case .SUBSCRIBE(let packet):
                try handleSub(packet: packet, ctx: ctx)
            case .PUBLISH(let packet):
                try handlePublish(packet: packet, ctx: ctx)
            case .PINGREQ(let packet):
                try handlePinreq(packet: packet, ctx: ctx)
            case .UNSUBSCRIBE(let packet):
                try handleUnsub(packet: packet, ctx: ctx)
            default:
                print("other packets")
            }
            
        } catch {
            errorCaught(ctx: ctx, error: error)
        }
    }
    
    public func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        print("error: ", error)
        
        // As we are not really interested getting notified on success or failure we just pass nil as promise to
        // reduce allocations.
        ctx.close(promise: nil)
    }
    
    func handleConnection(packet: MQTTConnecPacket, ctx: ChannelHandlerContext) throws {
        guard let password = packet.password else {
            return
        }
        let pwStr = String(data: password, encoding: .utf8)
        guard packet.userName == "yanghuan", pwStr == "yhyhyh" else {
            return
        }
        
        let connack = MQTTConnAckPacket(isSessionPresent: false, returnCode: MQTTConnectReturnCode(0x00))
        
        ctx.write(self.wrapOutboundOut(.CONNACK(packet: connack)), promise: nil)
        print("accept coonection")
    }
    
    func handleSub(packet: MQTTSubscribePacket, ctx: ChannelHandlerContext) throws {
        var grantedQos: [UInt8] = []
        for sub in packet.subscriptions {
            var channels: [subscribtion] = subscribtions[sub.topicFilter] ?? []
            channels.append(subscribtion(channel: ctx.channel, qos: sub.requestedQoS))
            subscribtions[sub.topicFilter] = channels
            grantedQos.append(min(sub.requestedQoS.rawValue, maxGrantedQosLevel))
        }
        let subAckPacket = MQTTSubAckPacket(messageId: packet.messageId, grantedQoSLevels: grantedQos)
        
        ctx.write(self.wrapOutboundOut(.SUBACK(packet: subAckPacket)), promise: nil)
        for (topic, subs) in subscribtions {
            print("topic: \(topic), count: \(subs.count)")
        }
        
    }
    
    func handlePublish(packet: MQTTPublishPacket, ctx: ChannelHandlerContext) throws {
        let topic = packet.topic
        guard let subs = subscribtions[topic] else {
            return
        }
        for sub in subs {
            let messageId = packet.messageId
            if sub.qos != .AT_MOST_ONCE && messageId == nil {
                continue
            }
            let pubPacket = MQTTPublishPacket(topic: topic, payload: packet.payload, messageId: messageId)
            if sub.qos == .AT_LEAST_ONCE {
                let pubAckPacket = MQTTOnlyMessageIdPacket(type: .PUBACK, messageId: messageId!)
                ctx.writeAndFlush(wrapOutboundOut(.PUBACK(packet: pubAckPacket!)), promise: nil)
            }
            if sub.qos == .EXACTLY_ONCE {
                let pubAckPacket = MQTTOnlyMessageIdPacket(type: .PUBREC, messageId: messageId!)
                ctx.writeAndFlush(wrapOutboundOut(.PUBREC(packet: pubAckPacket!)), promise: nil)
            }
            sub.channel.write(wrapOutboundOut(.PUBLISH(packet: pubPacket)), promise: nil)
        }
        print("get pub packet:\(topic)")
    }
    
    func handlePinreq(packet: MQTTOnlyFixedHeaderPacket, ctx: ChannelHandlerContext) throws {
        let pingresp = MQTTOnlyFixedHeaderPacket(type: .PINGRESP)
        ctx.writeAndFlush(wrapOutboundOut(.PINGRESP(packet: pingresp!)), promise: nil)
        print("ping pong")
    }
    
    func handleUnsub(packet: MQTTUnSubscribekPacket, ctx: ChannelHandlerContext) throws {
        //        let pingresp = MQTTOnlyFixedHeaderPacket(type: .PINGRESP)
        //        ctx.write(wrapOutboundOut(.PINGRESP(packet: pingresp!)), promise: nil)
        //        print("ping pong")
    }
}

// We need to share the same ChatHandler for all as it keeps track of all
// connected clients. For this ChatHandler MUST be thread-safe!
let server = MQTTServerHandler()

let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
let bootstrap = ServerBootstrap(group: group)
    // Specify backlog and enable SO_REUSEADDR for the server itself
    .serverChannelOption(ChannelOptions.backlog, value: 256)
    .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
    
    // Set the handlers that are applied to the accepted Channels
    .childChannelInitializer { channel in
        channel.pipeline.addHandlers([MQTTDecoder(), MQTTEncoder()], first: true).then { v in
            channel.pipeline.add(handler: server)
        }
    }
    
    // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
    .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
    .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
    .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
    .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
defer {
    try! group.syncShutdownGracefully()
}

// First argument is the program path
let arguments = CommandLine.arguments
let arg1 = arguments.dropFirst().first
let arg2 = arguments.dropFirst(2).first

let defaultHost = "::"
let defaultPort = 9999

enum BindTo {
    case ip(host: String, port: Int)
    case unixDomainSocket(path: String)
}

let bindTarget: BindTo
switch (arg1, arg1.flatMap(Int.init), arg2.flatMap(Int.init)) {
case (.some(let h), _ , .some(let p)):
    /* we got two arguments, let's interpret that as host and port */
    bindTarget = .ip(host: h, port: p)
    
case (let portString?, .none, _):
    // Couldn't parse as number, expecting unix domain socket path.
    bindTarget = .unixDomainSocket(path: portString)
    
case (_, let p?, _):
    // Only one argument --> port.
    bindTarget = .ip(host: defaultHost, port: p)
    
default:
    bindTarget = .ip(host: defaultHost, port: defaultPort)
}

let channel = try { () -> Channel in
    switch bindTarget {
    case .ip(let host, let port):
        return try bootstrap.bind(host: host, port: port).wait()
    case .unixDomainSocket(let path):
        return try bootstrap.bind(unixDomainSocketPath: path).wait()
    }
    }()

guard let localAddress = channel.localAddress else {
    fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
}
print("Server started and listening on \(localAddress)")

// This will never unblock as we don't close the ServerChannel.
try channel.closeFuture.wait()

print("ChatServer closed")
