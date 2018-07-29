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
typealias decodeResults<T> = (needMore: Bool , result: T?)
typealias decodeResult<T> = (decoded: Int, result: T?)
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
    /* Connect */
    static let USERNAME_MASK: Byte = 0x80
    static let PASSWORD_MASK: Byte = 0x40
    static let WILL_RETAIN_MASK: Byte = 0x20
    static let WILL_QOS_MASK: Byte = 0x18
    static let WILL_QOS_SHIFT: Byte = 3
    static let WILL_FLAG_MASK: Byte = 0x04
    static let CLEAN_SESSION_MASK: Byte = 0x02
    static let CONNEC_RESERVE_MASK: Byte = 0x01
}

struct MQTTMessageDecoder {

    func decodeVariableHeader(fixedHeader: MQTTPacketFixedHeader, buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketVariableHeader> {
        switch fixedHeader.MqttMessageType {
        case .CONNEC:
            return try decodeConnectVariableHeader(fixedHeader: fixedHeader, buffer: &buffer)
        case .PUBLISH:
            return try decodePublishVariableHeader(fixedHeader: fixedHeader, buffer: &buffer)
        case .PINGREQ, .PINGRESP, .DISCONNECT:
            return (0, nil)
        default:
            return (0, nil)
        }
    }
    
    func decodePayloads(variableHeader: MQTTPacketVariableHeader?, packetType: MQTTControlPacketType, remainLength: Int, buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketPayload> {
        switch packetType {
        case .CONNEC:
            return try decodeConnectPayloads(variableHeader: variableHeader, buffer: &buffer)
        case .PUBLISH:
            return try decodePublishPayloads(remainLength: remainLength, buffer: &buffer)
        case .PINGREQ, .PINGRESP, .DISCONNECT:
            return (0, nil)
        default:
            return (0 ,nil)
        }
    }
    
}

// decode fixedHeader
extension MQTTMessageDecoder {
    func decodeFixedHeader(buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketFixedHeader> {
        typealias UnsignedByte = UInt8
        
        var decoded = 0
        let startIndex = buffer.readerIndex
        
        guard let firstByte = buffer.getInteger(at: startIndex, as: UInt8.self) else {
            return (0, nil)
        }
        
        decoded += 1
        
        guard let messageType = MQTTControlPacketType(rawValue: firstByte >> DecodeConsts.CMD_SHIFT) else {
            throw MQTTDecodeError.invalidMessageType
        }
        
        let retain = firstByte & DecodeConsts.RETAIN_MASK == 0
        let qos = (firstByte >> DecodeConsts.QOS_SHIFT) & DecodeConsts.QOS_MASK
        let dup = firstByte & DecodeConsts.DUP_MASK == 0
        
        var loops = 0;
        var nextByte: UInt8
        var remainingLength = 0;
        var multiplier = 1;
        repeat {
            guard let byte = buffer.getInteger(at: startIndex + decoded, as: UInt8.self) else {
                return (0, nil)
            }
            decoded += 1
            loops += 1;
            nextByte = byte
            remainingLength += Int(nextByte & DecodeConsts.LENGTH_MASK) * multiplier;
            multiplier *= Int(DecodeConsts.LENGTH_FIN_MASK);
        } while ((nextByte & DecodeConsts.LENGTH_FIN_MASK) != 0 && loops < 4);
        
        // MQTT protocol limits Remaining Length to 4 bytes
        
        if (loops == 4 && (nextByte & DecodeConsts.LENGTH_FIN_MASK) != 0) {
            throw MQTTDecodeError.remainLengthExceed
        }
        
        let fixedHeader = MQTTPacketFixedHeader(MqttMessageType: messageType, isDup: dup, qosLevel: MQTTQos(rawValue: qos)!, isRetain: retain, remainingLength: remainingLength)
        
        try MQTTUtils.validateFixedHeader(fixedHeader)
        
        return (decoded, fixedHeader)
    }
}

// utils funcs
extension MQTTMessageDecoder {
    internal func decodeMsbLsb(bytes: [UInt8]) -> UInt32 {
        let msbSize = bytes[0]
        let lsbSize = bytes[1]
        let result = UInt32(msbSize << 8 | lsbSize)
        return result
    }
    
    func decodeMsbLsb(buffer: inout ByteBuffer, at: Int,  min: UInt16 = 0, max: UInt16 = UInt16.max) -> decodeResult<Int> {
        guard let bytes = buffer.getBytes(at: at, length: 2) else {
            return decodeResult(0, nil)
        }
        let msbSize = bytes[0]
        
        let lsbSize = bytes[1]
        let result = Int(msbSize << 8 | lsbSize)
        //        if result < min || result > max {
        //            return(false, nil)
        //        }
        return decodeResult(2, result)
    }
    
    func decodeString(buffer: inout ByteBuffer, at: Int, minBytes: Int16 = 0, maxBytes: Int = Int.max) throws -> decodeResult<String> {
        let (decoded, size) = decodeMsbLsb(buffer: &buffer, at: at)
        guard decoded != 0 else {
            return (0, nil)
        }
        if size! < minBytes || Int(size!) > maxBytes {
            if Int(size!) > maxBytes {
                throw MQTTDecodeError.exceedMaxStringLength
            }
            return decodeResult(decoded + size!, nil)
        }
        
        guard let string = buffer.getString(at: at + decoded, length: size!) else {
            return decodeResult(0, nil)
        }
        
        return decodeResult(decoded + size!, string)
    }
    
    func decodeByteArray(buffer: inout ByteBuffer, at: Int) -> decodeResult<Data> {
        let (decoded, size) = decodeMsbLsb(buffer: &buffer, at: at)
        guard decoded != 0 else {
            return decodeResult(0, nil)
        }
        
        guard let data = buffer.getBytes(at: at + decoded, length: size!) else {
            // move back readindex
            return decodeResult(0, nil)
        }
        return (2 + size!, Data(data))
    }
}

// decode variableheader
extension MQTTMessageDecoder {
    func decodeConnectVariableHeader(fixedHeader: MQTTPacketFixedHeader? = nil, buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketVariableHeader> {
        
        // decoded variableHeader, we have sured there is enough buffer
        do {
            let startIndex = buffer.readerIndex
            var decoded = 0
            let (d1, protocalName) = try decodeString(buffer: &buffer, at: startIndex + decoded)
            
            decoded += d1
            
            let protocolLevel = buffer.getInteger(at: startIndex + decoded, as: UInt8.self)!
            decoded += 1
            
            try MQTTUtils.validateProtocolNameAndLevel(version: (name: protocalName!, level: protocolLevel))
            
            let b1 = buffer.getInteger(at: startIndex + decoded ,as: UInt8.self)
            
            assert(b1 != nil, "should have enough buffer")
            decoded += 1
            
            if protocalName! == "MQTT" && (b1! & DecodeConsts.CONNEC_RESERVE_MASK) != 0 {
                throw MQTTDecodeError.invalidVariableHeader(Str: "no zero Reserved Flag")
            }
            
            let (d2, keepAlive) = decodeMsbLsb(buffer: &buffer, at: decoded)
            
            decoded += d2
            
            let hasUserName = b1! & DecodeConsts.USERNAME_MASK == DecodeConsts.USERNAME_MASK
            let hasPassword = (b1! & DecodeConsts.PASSWORD_MASK) == DecodeConsts.PASSWORD_MASK;
            if !hasUserName && hasPassword {
                throw MQTTDecodeError.invalidVariableHeader(Str: "password flag should be 0 when username flag is 0")
            }
            
            let willRetain = (b1! & DecodeConsts.WILL_RETAIN_MASK) == DecodeConsts.WILL_RETAIN_MASK;
            let willQos = (b1! & DecodeConsts.WILL_QOS_MASK) >> DecodeConsts.WILL_QOS_SHIFT;
            let willFlag = (b1! & DecodeConsts.WILL_FLAG_MASK) == DecodeConsts.WILL_FLAG_MASK;
            let cleanSession = (b1! & DecodeConsts.CLEAN_SESSION_MASK) == DecodeConsts.CLEAN_SESSION_MASK;
            
            let vheader = MQTTConnectVariableHeader(name: protocalName!, version: protocolLevel, hasUserName: hasUserName, hasPassword: hasPassword, isWillRetain: willRetain, willQos: MQTTQos(rawValue: willQos)!, isWillFlag: willFlag, isCleanSession: cleanSession, keepAliveTimeSeconds: UInt16(keepAlive!))
            
            return decodeResult(decoded, MQTTPacketVariableHeader.CONNEC(variableHeader: vheader))
            
        } catch MQTTDecodeError.exceedMaxStringLength {
            throw MQTTDecodeError.invalidProtocolName
        }
    }

    func decodePublishVariableHeader(fixedHeader: MQTTPacketFixedHeader?, buffer: inout ByteBuffer) throws -> (decoded: Int, result: MQTTPacketVariableHeader?) {
        guard let fixedHeader = fixedHeader else {
            fatalError("this shouldnt happen")
        }
        let startIndex = buffer.readerIndex
        
        var decoded = 0
        
        let (d1, topicName) = try self.decodeString(buffer: &buffer, at: startIndex)
        decoded += d1
        guard let topic = topicName else {
            throw MQTTDecodeError.invalidVariableHeader(Str: "publish packet need topicName")
        }
        
        var messageId = -1
        
        if fixedHeader.qosLevel > .AT_LEAST_ONCE {
            let (d2, id) = self.decodeMsbLsb(buffer: &buffer, at: decoded)
            decoded += d2
            messageId = Int(id!)
        }
        let vh = MQTTPublishVariableHeader(topicName: topic, packetId: messageId)
        
        return decodeResult(decoded, .PUBLISH(variableHeader: vh))
    }
}

// decode payloads
extension MQTTMessageDecoder {
    func decodeConnectPayloads(variableHeader: MQTTPacketVariableHeader?, buffer: inout ByteBuffer) throws -> decodeResult<MQTTPacketPayload> {
        
        // because we have checked the bytes if enough before we enter this func ,so we dont check needmore
        if case let .CONNEC(variableHeader) = variableHeader! {
            do {
                let startIndex = buffer.readerIndex
                
                var decoded = 0
                
                let (d1, clientId) = try decodeString(buffer: &buffer, at: startIndex + decoded)
                decoded += d1
                
                try MQTTUtils.validateClientIdentifier(version: (variableHeader.name, variableHeader.version), clientId: clientId)
                
                var decodedWillTopic: String?
                var decodedWillMessage: Data?
                var decodedUserName: String?
                var decodedPassword: Data?
                
                if variableHeader.isWillFlag {
                    let (d3, willTopic) = try decodeString(buffer: &buffer, at: startIndex + decoded)
                    
                    decoded += d3
                    decodedWillTopic = willTopic
                    
                    let (d4, willMessage) =  decodeByteArray(buffer: &buffer, at: startIndex + decoded)
                    decoded += d4
                    decodedWillMessage = willMessage
                }
                
                if variableHeader.hasUserName {
                    
                    let (d5, userName) = try decodeString(buffer: &buffer, at: startIndex + decoded)
                    decoded += d5
                    decodedUserName = userName
                    
                    let (d6, password) = decodeByteArray(buffer: &buffer, at: startIndex + decoded)
                    decoded += d6
                    decodedPassword = password
                }
                
                let payload = MQTTConnectPayload(clientIdentifier: clientId!, willTopic: decodedWillTopic, willMessage: decodedWillMessage, userName: decodedUserName, password: decodedPassword)
                
                return decodeResult(decoded, MQTTPacketPayload.CONNEC(payload: payload))
            }
            
        }
        fatalError("this shouldnt happen")
    }
    
    
    func decodePublishPayloads(remainLength: Int, buffer: inout ByteBuffer) throws -> (decoded: Int, result: MQTTPacketPayload?) {
        guard remainLength >= 0 else {
            fatalError("this shouldnt happen")
        }
        
        guard let res = buffer.getBytes(at: buffer.readerIndex, length: remainLength) else {
            return (0, nil)
        }
        
        return (remainLength, .PUBLISH(payload: Data(res)))
    }
}

