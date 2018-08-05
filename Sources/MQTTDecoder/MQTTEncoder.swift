//
//  MQTTEncoder.swift
//  MQTTDecoder
//
//  Created by yh on 2018/5/18.
//

import Foundation
import NIO

public final class MQTTEncoder: ChannelOutboundHandler{
    public typealias OutboundIn = MQTTPacket
    public typealias OutboundOut = ByteBuffer
    
    public init () {
        
    }
    
    public func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let packet = self.unwrapOutboundIn(data)
//        print(packet)
        do {
            try _write(ctx: ctx, packet: packet)
        } catch {
            ctx.fireErrorCaught(error)
            ctx.close(promise: nil)
        }
    }

    func _write(ctx: ChannelHandlerContext, packet: MQTTPacket) throws {
        switch packet {
        case .CONNEC(let packet):
            try writeConnectPacket(p: packet, ctx: ctx)
        case .CONNACK(let packet):
            try writeConnAckPacket(p: packet, ctx: ctx)
        case .PUBLISH(let packet):
            try writePublishPacket(p: packet, ctx: ctx)
        case .PINGREQ(let packet):
            try writePacketWithOnlyFixedheader(p: packet, ctx: ctx)
        case .PINGRESP(let packet):
            try writePacketWithOnlyFixedheader(p: packet, ctx: ctx)
        case .PUBACK(let packet):
            try writeOnlyMessageIdPacket(p: packet, ctx: ctx)
        case .PUBREC(let packet):
            try writeOnlyMessageIdPacket(p: packet, ctx: ctx)
        case .PUBREL(let packet):
            try writeOnlyMessageIdPacket(p: packet, ctx: ctx)
        case .PUBCOMP(let packet):
            try writeOnlyMessageIdPacket(p: packet, ctx: ctx)
        case .SUBSCRIBE(let packet):
            try writeSubscribePacket(p: packet, ctx: ctx)
        case .SUBACK(let packet):
            try writeSubAckPacket(p: packet, ctx: ctx)
        case .UNSUBSCRIBE(let packet):
            try writeUnsubscribePacket(p: packet, ctx: ctx)
        case .UNSUBACK(let packet):
            try writeUnsubAckPacket(p: packet, ctx: ctx)
        case .DISCONNECT(let packet):
            try writePacketWithOnlyFixedheader(p: packet, ctx: ctx)

        }
    }
    func writeConnAckPacket(p: MQTTConnAckPacket, ctx: ChannelHandlerContext) throws {
        var buf = ctx.channel.allocator.buffer(capacity: 4)
        buf.write(byte: encodeFixedHeder(p.fixedHeader))
        buf.write(byte: 2)
        buf.write(byte: p.variableHeader.isSessionPresent ? 0x01 : 0x00)
        buf.write(byte: p.variableHeader.connectReturnCode.rawValue())
        ctx.write(self.wrapOutboundOut(buf), promise: nil)
        ctx.flush()
    }
    
    func writeConnectPacket(p: MQTTConnecPacket, ctx: ChannelHandlerContext) throws {
        let fixedHeader = p.fixedHeader
        let variableHeader = p.variableHeader
        let payload = p.payload
        var payloadSize = 0
        var variableHeaderSize = 0
        guard !variableHeader.hasUserName && variableHeader.hasPassword else {
            // TODO
            throw MQTTDecodeError.decodeError
        }
        try MQTTUtils.validateClientIdentifier(version: (variableHeader.name, variableHeader.version), clientId: payload.clientIdentifier)
        payloadSize += 2 + payload.clientIdentifier.lengthOfBytes(using: .utf8)
        if variableHeader.isWillFlag {
            payloadSize += 2 + (payload.willTopic?.lengthOfBytes(using: .utf8) ?? 0)
            payloadSize += 2 + (payload.willMessage?.count ?? 0)
        }
        if variableHeader.hasUserName {
            payloadSize += 2 + (payload.userName?.lengthOfBytes(using: .utf8) ?? 0)
        }
        
        variableHeaderSize += 2 + variableHeader.name.lengthOfBytes(using: .utf8) + 4
        let variablePartSize = payloadSize + variableHeaderSize
        
        let fixedHeaderSize = 1 + encodeVariablePartSize(size: variablePartSize)
        
        var buf = ctx.channel.allocator.buffer(capacity: fixedHeaderSize + variablePartSize)

        buf.write(byte: encodeFixedHeder(fixedHeader))
        writeVariableLength(buffer: &buf, length: variablePartSize)
        buf.encodeWrite(str: variableHeader.name)
        buf.write(byte: variableHeader.version)
        buf.write(byte: encodeConnVariableHeaderFlag(variableHeader))
        buf.write(integer: variableHeader.keepAliveTimeSeconds)
        
        buf.encodeWrite(str: payload.clientIdentifier)
        
        if variableHeader.isWillFlag {
            buf.encodeWrite(str: payload.willTopic)
            buf.encodeWrite(data: payload.willMessage)
        }
        
        if variableHeader.hasPassword {
            buf.encodeWrite(str: payload.userName)
        }
        
        if variableHeader.hasPassword {
            buf.encodeWrite(data: payload.password)
        }

        ctx.writeAndFlush(wrapOutboundOut(buf), promise: nil)
    }
    
    func writePublishPacket(p: MQTTPublishPacket, ctx: ChannelHandlerContext) throws {
        let fixedHeader = p.fixedHeader
        let variableHeader = p.variableHeader
        let payload = p.payload
        
        var payloadSize = 0
        var variableHeaderSize = 0
        
        variableHeaderSize += 2
        variableHeaderSize += variableHeader.topicName.lengthOfBytes(using: .utf8)
        variableHeaderSize += fixedHeader.qosLevel > .AT_MOST_ONCE ? 2 : 0
        
        payloadSize += payload?.count ?? 0
        
        let variablePartSize = payloadSize + variableHeaderSize
        let fixedHeaderSize = 1 + encodeVariablePartSize(size: variablePartSize)
        
        var buf = ctx.channel.allocator.buffer(capacity: fixedHeaderSize + variablePartSize)
        
        buf.write(byte: encodeFixedHeder(fixedHeader))
        writeVariableLength(buffer: &buf, length: variablePartSize)
        buf.encodeWrite(str: variableHeader.topicName)
        
        if fixedHeader.qosLevel > .AT_MOST_ONCE {
            buf.write(short: variableHeader.packetId!)
        }
        if let payload = payload {
            buf.write(bytes: payload)
        }
        ctx.writeAndFlush(self.wrapOutboundOut(buf), promise: nil)
    }
    
    func writeSubscribePacket(p: MQTTSubscribePacket, ctx: ChannelHandlerContext) throws {
        let fixedHeader = p.fixedHeader
        let variableHeader = p.variableHeader
        let payload = p.payload
        
        var payloadSize = 0
        let variableHeaderSize = 2
        
        for sub in payload.subscriptions {
            // encode string
            payloadSize += 2 + sub.topicFilter.lengthOfBytes(using: .utf8)
            // qos
            payloadSize += 1
        }
        
        let variablePartSize = variableHeaderSize + payloadSize
        
        let fixedHeaderSize = 1 + encodeVariablePartSize(size: variablePartSize)
        
        var buf = ctx.channel.allocator.buffer(capacity: fixedHeaderSize + variablePartSize)
        
        buf.write(byte: encodeFixedHeder(fixedHeader))
        
        writeVariableLength(buffer: &buf, length: variablePartSize)
        
        buf.write(short: variableHeader.messageId)
        
        for sub  in payload.subscriptions {
            buf.encodeWrite(str: sub.topicFilter)
            buf.write(byte: sub.requestedQoS.rawValue)
        }
        
        ctx.write(wrapOutboundOut(buf), promise: nil)
        
    }
    
    func writeSubAckPacket(p: MQTTSubAckPacket, ctx: ChannelHandlerContext) throws {
        
        let fixedHeader = p.fixedHeader
        let variableHeader = p.variableHeader
        let payload = p.payload
        
        let variableHeaderSize = 2
        let payloadSize = payload.grantedQoSLevels.count

        
        let variablePartSize = variableHeaderSize + payloadSize
        
        let fixedHeaderSize = 1 + encodeVariablePartSize(size: variablePartSize)
        
        var buf = ctx.channel.allocator.buffer(capacity: fixedHeaderSize + variablePartSize)
        
        buf.write(byte: encodeFixedHeder(fixedHeader))
        
        writeVariableLength(buffer: &buf, length: variablePartSize)
        
        buf.write(short: variableHeader.messageId)
        
        for qos in payload.grantedQoSLevels {
            buf.write(byte: qos)
        }
        
        ctx.write(wrapOutboundOut(buf), promise: nil)
    }
    
    func writeUnsubscribePacket(p: MQTTUnSubscribekPacket, ctx: ChannelHandlerContext) throws {
        let fixedHeader = p.fixedHeader
        let variableHeader = p.variableHeader
        let payload = p.payload
        
        var payloadSize = 0
        let variableHeaderSize = 2
        
        for topic in payload.topicFilters {
            // encode string
            payloadSize += 2 + topic.lengthOfBytes(using: .utf8)
        }
        
        let variablePartSize = variableHeaderSize + payloadSize
        
        let fixedHeaderSize = 1 + encodeVariablePartSize(size: variablePartSize)
        
        var buf = ctx.channel.allocator.buffer(capacity: fixedHeaderSize + variablePartSize)
        
        buf.write(byte: encodeFixedHeder(fixedHeader))
        
        writeVariableLength(buffer: &buf, length: variablePartSize)
        
        buf.write(short: variableHeader.messageId)
        
        for topic in payload.topicFilters {
            buf.encodeWrite(str: topic)
        }
        
        ctx.write(wrapOutboundOut(buf), promise: nil)
        
    }
    
    func writeOnlyMessageIdPacket(p: MQTTOnlyMessageIdPacket, ctx: ChannelHandlerContext) throws {
        let fixedHeader = p.fixedHeader
        let variableHeader = p.variableHeader
        let variableHeaderSize = 2

        let fixedHeaderSize = 1 + encodeVariablePartSize(size: variableHeaderSize)
        
        var buf = ctx.channel.allocator.buffer(capacity: fixedHeaderSize + variableHeaderSize)
        
        buf.write(byte: encodeFixedHeder(fixedHeader))
        
        writeVariableLength(buffer: &buf, length: variableHeaderSize)
        
        buf.write(short: variableHeader.messageId)
        ctx.write(wrapOutboundOut(buf), promise: nil)

    }
    func writeUnsubAckPacket(p: MQTTUnsubackPacket, ctx: ChannelHandlerContext) throws {
        let onlyMessageIdpacket = MQTTOnlyMessageIdPacket(fixedHeader: p.fixedHeader, variableHeader: p.variableHeader)
        try writeOnlyMessageIdPacket(p: onlyMessageIdpacket, ctx: ctx)
    }
    
    func writePacketWithOnlyFixedheader(p: MQTTOnlyFixedHeaderPacket, ctx: ChannelHandlerContext) throws {
        let fixedHeader = p.fixedHeader
        var buf = ctx.channel.allocator.buffer(capacity: 2)
        buf.write(byte: encodeFixedHeder(fixedHeader))
        buf.write(byte: 0)
        ctx.write(wrapOutboundOut(buf), promise: nil)
    }

    func writeVariableLength(buffer: inout ByteBuffer, length: Int) {
        var num = length
        repeat {
            var digit = num % 128
            num /= 128
            if num > 0 {
                digit |= 0x80
            }
            buffer.write(byte: UInt8(digit))
        } while num > 0;
    }
    
    func encodeVariablePartSize(size: Int) -> Int {
        var count = 0
        var size = size
        repeat {
            size /= 128
            count += 1
        } while size > 0
        
        return count;
    }
    
    func encodeFixedHeder(_ fixedHeader: MQTTPacketFixedHeader) -> UInt8 {
        var res: UInt8 = 0
        res |= fixedHeader.messageType.rawValue << 4
        if fixedHeader.isDup {
            res |= 0x08
        }
        res |= fixedHeader.qosLevel.rawValue << 1
        
        if fixedHeader.isRetain {
            res |= 0x01
        }
        return res
    }
    
    func encodeConnVariableHeaderFlag(_ variableHeader: MQTTConnectVariableHeader) -> UInt8 {
        var flagByte: UInt8 = 0
        
        if variableHeader.hasUserName {
            flagByte |= 0x80
        }
        if variableHeader.hasPassword {
            flagByte |= 0x40
        }
        if variableHeader.isWillRetain{
            flagByte |= 0x20
        }
        flagByte |= (variableHeader.willQos.rawValue & 0x03) << 3;
        if variableHeader.isWillFlag {
            flagByte |= 0x04
        }
        if variableHeader.isCleanSession {
            flagByte |= 0x02
        }
        
        return flagByte;
    }
}

extension ByteBuffer {
    mutating func write(byte: UInt8) {
        _ = write(integer: byte)
    }
    
    mutating func encodeWrite(str: String?) {
        guard let str = str else {
            return
        }
        let len = str.lengthOfBytes(using: .utf8)
        write(short: len)
        write(string: str)
    }
    
    mutating func encodeWrite(data: Data?) {
        guard let data = data else {
            return
        }
        let len = data.count
        write(short: len)
        write(bytes: data)
    }
    
    mutating func write(short: Int) {
        _ = write(integer: UInt16(short))
    }
}
