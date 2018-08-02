//
//  MQTTEncoder.swift
//  MQTTDecoder
//
//  Created by yh on 2018/5/18.
//

import Foundation
import NIO

final class MQTTEncoder: ChannelOutboundHandler{
    typealias OutboundIn = MQTTPacket
    typealias OutboundOut = ByteBuffer

    func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let packet = self.unwrapOutboundIn(data)
        print(packet)
        do {
            try _write(ctx: ctx, packet: packet)
        } catch {
            ctx.fireErrorCaught(error)
            ctx.close(promise: nil)
        }
    }

    func _write(ctx: ChannelHandlerContext, packet: MQTTPacket) throws {
        let variableHeaderLength = caculateVariableHeaderLength(p: packet)
//        let payloadLength = caculatePayloadsLength(p: packet)
        switch packet {
        case let .CONNEC(packet):
            try writeConnectPacket(p: packet, ctx: ctx)
        case let .CONNACK(packet):
            try writeConnAckPacket(p: packet, ctx: ctx)
        default:
            return
        }
    }
    func writeConnAckPacket(p: MQTTConnAckPacket, ctx: ChannelHandlerContext) throws {
        var buf = ctx.channel.allocator.buffer(capacity: 4)
        buf.write(byte: p.fixedHeader.firstByte())
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

        ctx.write(self.wrapOutboundOut(buf))
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
    
    
    func caculateVariableHeaderLength(p: MQTTPacket) ->Int {
        
        return 0
    }
    
    func encodeVariablePartSize(size: Int) -> Int {
        var count = 0
        var size = size
        
        repeat {
            size /= 128
            
            count += 2
        } while size > 0
        
        return count;
    }
    
    func encodeFixedHeder(_ fixedHeader: MQTTPacketFixedHeader) -> UInt8 {
        var res: UInt8 = 0
        res |= fixedHeader.MqttMessageType.rawValue << 4
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
