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
        var buf = ctx.channel.allocator.buffer(capacity: 4)
        
    }
}

extension ByteBuffer {
    mutating func write(byte: UInt8) {
        _ = write(integer: byte)
    }
}
