//
//  MQTTFixedHeader.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/5/4.
//

import Foundation

struct MQTTPacketFixedHeader {
    let MqttMessageType: MQTTControlPacketType
    let isDup: Bool
    let qosLevel:MQTTQos
    let isRetain: Bool
    let remainingLength: Int?
    
    func firstByte() -> UInt8 {
        var res: UInt8 = 0
        res |= MqttMessageType.rawValue << 4
        if isDup {
            res |= 0x08
        }
        res |= qosLevel.rawValue << 1
        
        if isRetain {
            res |= 0x01
        }
        return res
    }
}

enum MQTTControlPacketType: UInt8 {
    case CONNEC = 1
    case CONNACK
    case PUBLISH
    case PUBACK
    case PUBREC
    case PUBREL
    case PUBCOMP
    case SUBSCRIBE
    case SUBACK
    case UNSUBSCRIBE
    case UNSUBACK
    case PINGREQ
    case PINGRESP
    case DISCONNECT
    func value(of: MQTTControlPacketType) -> UInt8{
        return of.rawValue
    }
}

//struct MQTTVersion {
//    let name: String
//    let level: UInt8
//    
//    init(protocolName: String, protocolLevel: UInt8) throws {
//        switch (protocolName, protocolLevel) {
//        case ("MQTT", 4), ("MQIsdp", 3):
//            name = protocolName
//            level = protocolLevel
//        default:
//            throw MQTTDecodeError.notMatchedProtocolLevel
//        }
//    }
//}


enum MQTTQos: UInt8 {
    case AT_MOST_ONCE = 0
    case AT_LEAST_ONCE
    case EXACTLY_ONCE
//    static func > (lhs: MQTTQos, rhs: MQTTQos) -> Bool {
//        return lhs.rawValue > rhs.rawValue
//    }
}
extension MQTTQos{
    static func > (lhs: MQTTQos, rhs: MQTTQos) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }
}
