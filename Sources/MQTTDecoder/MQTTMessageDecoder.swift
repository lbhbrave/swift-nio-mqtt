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
typealias decodeResult<T> = (needMore: Bool , result: T?)

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
    static let CONNEC_RESERVE_MASK: Byte = 0x01

//    let CONNECT_HEADER = Buffer.from([let.codes['connect'] << let.CMD_SHIFT])
}

protocol MQTTAbstractMessageDecoder {
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

extension MQTTAbstractMessageDecoder {
    
    func decodeMsbLsb(buffer: inout ByteBuffer, min: UInt16 = 0, max: UInt16 = UInt16.max) -> decodeResult<UInt16> {
        guard let bytes = buffer.readBytes(length: 2) else {
            return decodeResult(true, nil)
        }
        let msbSize = bytes[0]
        let lsbSize = bytes[1]
        let result = UInt16(msbSize << 8 | lsbSize)
//        if result < min || result > max {
//            return(false, nil)
//        }
        
        return decodeResult(false, result)
    }
    
    func decodeString(buffer: inout ByteBuffer, minBytes: Int16 = 0, maxBytes: Int = Int.max) throws -> decodeResult<String> {
        let (needMore, size) = decodeMsbLsb(buffer: &buffer)
        if needMore {
            return decodeResult(true, nil)
        }
        if size! < minBytes || Int(size!) > maxBytes {
            if Int(size!) > maxBytes {
                throw MQTTDecodeError.exceedMaxStringLength
            }
            buffer.moveReaderIndex(to: Int(size!))
            return decodeResult(false, nil)
        }
        guard let string = buffer.readString(length: Int(size!)) else {
            buffer.moveReaderIndex(to: buffer.readerIndex - 2)
            return decodeResult(true, nil)
        }
        return decodeResult(false, string)
    }

    func decodeByteArray(buffer: inout ByteBuffer) -> decodeResult<Data> {
        let (needMore, size) = decodeMsbLsb(buffer: &buffer)
        if needMore { return decodeResult(true, nil) }
        guard let data = buffer.readBytes(length: Int(size!)) else {
            // move back readindex
            buffer.moveReaderIndex(to: buffer.readerIndex - 2)
            return decodeResult(true, nil)
        }
        return (false, Data(data))
    }
}

class MQTTConnectMessageDecoder: MQTTAbstractMessageDecoder {
    
    func decodeVariableHeader(buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketVariableHeader> {
        // connect variableHeader has 10 bytes, so we checked at beginning
        let connectVariableHeaderMax = 10
        guard buffer.readableBytes >= connectVariableHeaderMax else {
            return decodeResult(true, nil)
        }
        do {
            let (_, protocalName) = try decodeString(buffer: &buffer)
            let protocolLevel = buffer.readInteger(as: UInt8.self)!
            
            try MQTTUtils.validateProtocolNameAndLevel(version: (name: protocalName!, level: protocolLevel))

            let b1 = buffer.readInteger(as: UInt8.self)!

            if protocalName! == "MQTT" && (b1 & DecodeConsts.CONNEC_RESERVE_MASK) != 0 {
                throw MQTTDecodeError.invalidVariableHeader(Str: "no zero Reserved Flag")
            }
            
            let (_, keepAlive) = decodeMsbLsb(buffer: &buffer)

            let hasUserName = b1 & DecodeConsts.USERNAME_MASK == DecodeConsts.USERNAME_MASK
            let hasPassword = (b1 & DecodeConsts.PASSWORD_MASK) == DecodeConsts.PASSWORD_MASK;
            if !hasUserName && hasPassword {
                throw MQTTDecodeError.invalidVariableHeader(Str: "password flag should be 0 when username flag is 0")
            }
            
            let willRetain = (b1 & DecodeConsts.WILL_RETAIN_MASK) == DecodeConsts.WILL_RETAIN_MASK;
            let willQos = (b1 & DecodeConsts.WILL_RETAIN_MASK) >> DecodeConsts.WILL_QOS_SHIFT;
            let willFlag = (b1 & DecodeConsts.WILL_FLAG_MASK) == DecodeConsts.WILL_FLAG_MASK;
            let cleanSession = (b1 & DecodeConsts.CLEAN_SESSION_MASK) == DecodeConsts.CLEAN_SESSION_MASK;
            
            
            
            let vheader = MQTTConnectVariableHeader(name: protocalName!, version: protocolLevel, hasUserName: hasUserName, hasPassword: hasPassword, isWillRetain: willRetain, willQos: willQos, isWillFlag: willFlag, isCleanSession: cleanSession, keepAliveTimeSeconds: keepAlive!)
            
            return decodeResult(false, MQTTPacketVariableHeader.CONNEC(variableHeader: vheader))
            
        } catch MQTTDecodeError.exceedMaxStringLength {
            throw MQTTDecodeError.invalidProtocolName
        }
    }
    
    func decodePayloads(variableHeader: MQTTPacketVariableHeader?, buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketPayload> {
        // because we have checked the bytes if enough before we enter this func ,so we dont check needmore
        
        if case let .CONNEC(variableHeader) = variableHeader! {
            do {
                let (_, clientId) = try decodeString(buffer: &buffer)
                try MQTTUtils.validateClientIdentifier(version: (variableHeader.name, variableHeader.version), clientId: clientId)
                
                var decodedWillTopic: String?
                var decodedWillMessage: Data?
                var decodedUserName: String?
                var decodedPassword: Data?
                
                if variableHeader.isWillFlag {
                    (_, decodedWillTopic) = try decodeString(buffer: &buffer)
                    (_, decodedWillMessage) =  decodeByteArray(buffer: &buffer)
                }

                if variableHeader.hasUserName {
                    (_, decodedUserName) = try decodeString(buffer: &buffer)
                    (_, decodedPassword) = decodeByteArray(buffer: &buffer)
                }

                let payload = MQTTConnectPayload(clientIdentifier: clientId!, willTopic: decodedWillTopic, willMessage: decodedWillMessage, userName: decodedUserName, password: decodedPassword)

                return decodeResult(false, MQTTPacketPayload.CONNEC(payload: payload))
            }

        }
        fatalError("this shouldnt happen")
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


