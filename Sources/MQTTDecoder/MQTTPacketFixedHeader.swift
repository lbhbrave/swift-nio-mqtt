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
    let remainingLength: Int
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

enum MQTTQos: UInt8 {
    case AT_MOST_ONCE = 0
    case AT_LEAST_ONCE
    case EXACTLY_ONCE
    case RETAIN
}
