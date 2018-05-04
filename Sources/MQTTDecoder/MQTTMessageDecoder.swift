//
//  MQTTMessageDecoder.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/4/30.
//

import Foundation
import NIO
enum messageDecodeState {
    case idel
    case decodingVariableHeader
    case decodingPayload
}

typealias MQTTHeader = (type: MQTTControlPacketType, dup: Bool, qos: UInt8, retain: Bool)

internal struct DecodeConsts {
    typealias Byte = UInt8
    /* Header */
    static let CMD_SHIFT: Byte = 4
    static let CMD_MASK: Byte = 0xF0
    static let DUP_MASK: Byte = 0x08
    static let QOS_MASK: Byte = 0x03
    static let QOS_SHIFT: Byte = 1
    static let RETAIN_MASK: Byte = 0x01
    
    /* Length */
    static let LENGTH_MASK: Byte = 0x7F
    static let LENGTH_FIN_MASK: Byte = 0x80
    
    /* Connack */
    static let SESSIONPRESENT_MASK: Byte = 0x01
    
//    let SESSIONPRESENT_HEADER = Buffer.from([let.SESSIONPRESENT_MASK])
//    let CONNACK_HEADER = Buffer.from([let.codes['connack'] << let.CMD_SHIFT])
    
    /* Connect */
    static let USERNAME_MASK: Byte = 0x80
    static let PASSWORD_MASK: Byte = 0x40
    static let WILL_RETAIN_MASK: Byte = 0x20
    static let WILL_QOS_MASK: Byte = 0x18
    static let WILL_QOS_SHIFT: Byte = 3
    static let WILL_FLAG_MASK: Byte = 0x04
    static let CLEAN_SESSION_MASK: Byte = 0x02
//    let CONNECT_HEADER = Buffer.from([let.codes['connect'] << let.CMD_SHIFT])
}

protocol MQTTAbstractMessageDecoder {
    typealias decodeResult<T> = (needMore: Bool, result: T?)
    func decodeFixedHeader(firstByte: UInt8, buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketFixedHeader>
    func decodeVariableHeader(buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketVariableHeader>
    func decodePayloads(variableHeader: MQTTPacketVariableHeader?, buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketPayload>
}

extension MQTTAbstractMessageDecoder {
//    typealias variableHeaderType = Any
//    typealias payloadType = Data
    func decodeFixedHeader(firstByte: UInt8, buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketFixedHeader> {
        let startIndex = buffer.readerIndex
        typealias UnsignedByte = UInt8
        guard let messageType = MQTTControlPacketType(rawValue: firstByte >> DecodeConsts.CMD_SHIFT) else {
            throw MQTTDecodeError.invalidMessageType
        }
        
        
        let retain = firstByte & DecodeConsts.RETAIN_MASK == 0
        let qos = (firstByte >> DecodeConsts.CMD_SHIFT) & DecodeConsts.QOS_MASK
        let dup = firstByte & DecodeConsts.DUP_MASK == 0
        
        var loops = 0;
        var nextByte: UnsignedByte
        var remainingLength = 0;
        var multiplier = 1;
        repeat {
            guard let byte = buffer.readInteger(as: UnsignedByte.self) else {
                // need more data to caculate. but this whouldn't happen
                buffer.moveReaderIndex(to: startIndex)
                return (true, nil)
            }
            nextByte = byte
            remainingLength += Int(nextByte & DecodeConsts.LENGTH_MASK) * multiplier;
            multiplier *= Int(DecodeConsts.LENGTH_FIN_MASK);
            loops += 1;
        } while ((nextByte & DecodeConsts.LENGTH_FIN_MASK) != 0 && loops < 4);
        
        // MQTT protocol limits Remaining Length to 4 bytes
        if (loops == 4 && (nextByte & DecodeConsts.LENGTH_FIN_MASK) != 0) {
            throw MQTTDecodeError.remainLengthExceed
        }
        
        let fixedHeader = MQTTPacketFixedHeader(MqttMessageType: messageType, isDup: dup, qosLevel: MQTTQos(rawValue: qos)!, isRetain: retain, remainingLength: remainingLength)
        
        try MQTTUtils.validateFixedHeader(fixedHeader)

        return (false, fixedHeader)
    }
    
    
    func decodeVariableHeader(buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketVariableHeader> {
        return (false, nil)
    }
    
    func decodePayloads(variableHeader: MQTTPacketVariableHeader?, buffer: inout ByteBuffer) throws ->  decodeResult<MQTTPacketPayload> {
        return (false, nil)
    }
}

class MQTTConnectMessageDecoder: MQTTAbstractMessageDecoder {
    
    func decodePayloads(variableHeader: MQTTPacketVariableHeader?, buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketPayload> {
        
        return (false, nil)
    }
    

}

class MQTTMessageDecoder {
    static func decodeMessageType(type: UInt8) throws -> MQTTControlPacketType{
        guard let messageType = MQTTControlPacketType(rawValue: type >> DecodeConsts.CMD_SHIFT) else {
            throw MQTTDecodeError.invalidMessageType
        }
        return messageType
    }

    static func newDecoder(type: MQTTControlPacketType) -> MQTTAbstractMessageDecoder {
        switch type {
        case .CONNEC:
            return MQTTConnectMessageDecoder()
        default:
            fatalError("shouldn't happen")
        }
    }
}


