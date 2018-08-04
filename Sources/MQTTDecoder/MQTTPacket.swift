//
//  MqttPacket.swift
//  CNIOAtomics
//
//  Created by yanghuan on 2018/4/29.
//

import Foundation
import NIO
/*
 CONNECT    1    客户端到服务端    客户端请求连接服务端
 CONNACK    2    服务端到客户端    连接报文确认
 PUBLISH    3    两个方向都允许    发布消息
 PUBACK    4    两个方向都允许    QoS 1消息发布收到确认
 PUBREC    5    两个方向都允许    发布收到（保证交付第一步）
 PUBREL    6    两个方向都允许    发布释放（保证交付第二步）
 PUBCOMP    7    两个方向都允许    QoS 2消息发布完成（保证交互第三步）
 SUBSCRIBE    8    客户端到服务端    客户端订阅请求
 SUBACK    9    服务端到客户端    订阅请求报文确认
 UNSUBSCRIBE    10    客户端到服务端    客户端取消订阅请求
 UNSUBACK    11    服务端到客户端    取消订阅报文确认
 PINGREQ    12    客户端到服务端    心跳请求
 PINGRESP    13    服务端到客户端    心跳响应
 */

public enum MQTTPacket {
    case CONNEC(packet: MQTTConnecPacket)
    case PUBLISH(packet: MQTTPublishPacket)
    case CONNACK(packet: MQTTConnAckPacket)
    case PINGREQ(packet: MQTTOnlyFixedHeaderPacket)
    case PINGRESP(packet: MQTTOnlyFixedHeaderPacket)
    case PUBACK(packet: MQTTOnlyMessageIdPacket)
    case PUBREC(packet: MQTTOnlyMessageIdPacket)
    case PUBREL(packet: MQTTOnlyMessageIdPacket)
    case PUBCOMP(packet: MQTTOnlyMessageIdPacket)
    case SUBSCRIBE(packet: MQTTSubscribePacket)
    case SUBACK(packet: MQTTSubAckPacket)
    case UNSUBSCRIBE(packet: MQTTUnSubscribekPacket)
    case UNSUBACK(packet: MQTTUnsubackPacket)
    case DISCONNECT(packet: MQTTOnlyFixedHeaderPacket)
    
    init(fixedHeader: MQTTPacketFixedHeader, variableHeader: MQTTPacketVariableHeader?, payloads: MQTTPacketPayload?) {
        switch fixedHeader.messageType {
        case .CONNEC:
            if case let .CONNEC(variableHeader) = variableHeader!, case let .CONNEC(payload) = payloads!{
                let connectPacket = MQTTConnecPacket(fixedHeader: fixedHeader, variableHeader: variableHeader, payload: payload)
                self = .CONNEC(packet: connectPacket)
                return
            }
        case .CONNACK:
            if case let .CONNACK(variableHeader) = variableHeader! {
                let connackPacket = MQTTConnAckPacket(fixedHeader: fixedHeader, variableHeader: variableHeader)
                self = .CONNACK(packet: connackPacket);
                return
            }
        case .SUBSCRIBE:
            if case let .SUBSCRIBE(variableHeader) = variableHeader!, case let .SUBSCRIBE(payload) = payloads! {
                let subscribePacket = MQTTSubscribePacket(fixedHeader: fixedHeader, variableHeader: variableHeader, payload: payload)
                self = .SUBSCRIBE(packet: subscribePacket);
                return
            }
        case .UNSUBSCRIBE:
            if case let .UNSUBSCRIBE(variableHeader) = variableHeader!, case let .UNSUBSCRIBE(payload) = payloads! {
                let unsubscribePacket = MQTTUnSubscribekPacket(fixedHeader: fixedHeader, variableHeader: variableHeader, payload: payload)
                self = .UNSUBSCRIBE(packet: unsubscribePacket);
                return
            }
        case .PUBLISH:
            if case let .PUBLISH(variableHeader) = variableHeader!, case let .PUBLISH(payloads)? = payloads {
                let publishPacket = MQTTPublishPacket(fixedHeader: fixedHeader, variableHeader: variableHeader, payload: payloads)
                self = .PUBLISH(packet: publishPacket)
                return
            }
        case .PUBACK:
            if case let .PUBACK(variableHeader) = variableHeader! {
                let pubackPacket = MQTTOnlyMessageIdPacket(fixedHeader: fixedHeader, variableHeader: variableHeader)
                self = .PUBACK(packet: pubackPacket)
                return
            }
        case .PUBREL:
            if case let .PUBREL(variableHeader) = variableHeader! {
                let pubrelPacket = MQTTOnlyMessageIdPacket(fixedHeader: fixedHeader, variableHeader: variableHeader)
                self = .PUBREL(packet: pubrelPacket)
                return
            }
        case .PUBREC:
            if case let .PUBREC(variableHeader) = variableHeader! {
                let pubrecPacket = MQTTOnlyMessageIdPacket(fixedHeader: fixedHeader, variableHeader: variableHeader)
                self = .PUBREC(packet: pubrecPacket)
                return
            }
        case .PUBCOMP:
            if case let .PUBCOMP(variableHeader) = variableHeader! {
                let pubcompPacket = MQTTOnlyMessageIdPacket(fixedHeader: fixedHeader, variableHeader: variableHeader)
                self = .PUBCOMP(packet: pubcompPacket)
                return
            }
        case .PINGREQ:
            let pingReqPacket = MQTTOnlyFixedHeaderPacket(fixedHeader: fixedHeader)
            self = .PINGREQ(packet: pingReqPacket)
            return
        case .PINGRESP:
            let pingRespPacket = MQTTOnlyFixedHeaderPacket(fixedHeader: fixedHeader)
            self = .PINGRESP(packet: pingRespPacket)
            return
        case .SUBACK:
            if case let .SUBACK(variableHeader) = variableHeader!, case let .SUBACK(payloads)? = payloads {
                let pingReqPacket = MQTTSubAckPacket(fixedHeader: fixedHeader, variableHeader: variableHeader, payload: payloads)
                self = .SUBACK(packet: pingReqPacket)
                return
            }
        case .UNSUBACK:
            if case let .UNSUBACK(variableHeader) = variableHeader! {
                let unsubackPacket = MQTTUnsubackPacket(fixedHeader: fixedHeader, variableHeader: variableHeader)
                self = .UNSUBACK(packet: unsubackPacket)
                return
            }
        case .DISCONNECT:
            let disconnectPacket = MQTTOnlyFixedHeaderPacket(fixedHeader: fixedHeader)
            self = .DISCONNECT(packet: disconnectPacket)
            return
        }
        fatalError("this shouldnt happen")
    }
    
    init (fixedHeader: MQTTPacketFixedHeader) {
        self.init(fixedHeader: fixedHeader, variableHeader: nil, payloads: nil)
    }
    
    init (fixedHeader: MQTTPacketFixedHeader, variableHeader: MQTTPacketVariableHeader) {
        self.init(fixedHeader: fixedHeader, variableHeader: variableHeader, payloads: nil)
    }
    
    func fixedHeader() -> MQTTPacketFixedHeader? {
        
        if case let .PUBLISH(packet) = self {
            return packet.fixedHeader
        }
        
        if case let .CONNACK(packet) = self {
            return packet.fixedHeader
        }
        
        if case let .CONNEC(packet) = self {
            return packet.fixedHeader
        }
        return nil
    }
    
    func variableHeader() -> MQTTPacketVariableHeader? {
        
        if case let .PUBLISH(packet) = self {
            return .PUBLISH(variableHeader: packet.variableHeader)
        }
        
        if case let .CONNACK(packet) = self {
            return .CONNACK(variableHeader: packet.variableHeader)
        }
        
        if case let .CONNEC(packet) = self {
            return .CONNEC(variableHeader: packet.variableHeader)
        }
        
        return nil
    }
    
}

public struct MQTTConnecPacket {
    let fixedHeader: MQTTPacketFixedHeader
    let variableHeader: MQTTConnectVariableHeader
    let payload: MQTTConnectPayload
    
    public var userName: String? {
        return payload.userName
    }
    public var password: Data? {
        return payload.password
    }
}

public struct MQTTPublishPacket {
    let fixedHeader: MQTTPacketFixedHeader
    let variableHeader: MQTTPublishVariableHeader
    let payload: Data?
    
    var topic: String {
        return variableHeader.topicName
    }
    
    init(fixedHeader: MQTTPacketFixedHeader, variableHeader: MQTTPublishVariableHeader, payload: Data?) {
        self.fixedHeader = fixedHeader
        self.variableHeader = variableHeader
        self.payload = payload
    }
    
    init(topic: String, payload: String?, qos: MQTTQos = .AT_MOST_ONCE, dup: Bool = false, retain: Bool = false, messageId: Int?) {
        fixedHeader = MQTTPacketFixedHeader(messageType: .PUBLISH, isDup: dup, qosLevel: qos, isRetain: retain, remainingLength: 0)
        
        variableHeader = MQTTPublishVariableHeader(topicName: topic, packetId: messageId)
        self.payload = payload?.data(using: .utf8)
    }

}

public struct MQTTOnlyFixedHeaderPacket {
    let fixedHeader: MQTTPacketFixedHeader
}

public struct MQTTOnlyMessageIdPacket {
    let fixedHeader: MQTTPacketFixedHeader
    let variableHeader: MQTTMessageIdVariableHeader

    init(fixedHeader: MQTTPacketFixedHeader, variableHeader: MQTTMessageIdVariableHeader) {
        self.fixedHeader = fixedHeader
        self.variableHeader = variableHeader
    }

    init?(type: MQTTControlPacketType, messageId: Int) {
        switch type {
        case .PUBACK, .PUBREC, .PUBREL, .PUBCOMP:
            self.fixedHeader = MQTTPacketFixedHeader(messageType: type, isDup: false, qosLevel: .AT_LEAST_ONCE, isRetain: false, remainingLength: 2)
            self.variableHeader = MQTTMessageIdVariableHeader(messageId: messageId)
        default:
            return nil
        }
    }
}

public struct MQTTSubscribePacket {
    let fixedHeader: MQTTPacketFixedHeader
    let variableHeader: MQTTMessageIdVariableHeader
    let payload: MQTTSubscribePayload
    
    public var subscriptions: [MQTTTopicSubscriptions] {
        return payload.subscriptions
    }
    public var messageId: Int {
        return variableHeader.messageId
    }
}

public struct MQTTUnsubackPacket {
    let fixedHeader: MQTTPacketFixedHeader
    let variableHeader: MQTTMessageIdVariableHeader
}


public struct MQTTSubAckPacket {
    let fixedHeader: MQTTPacketFixedHeader
    let variableHeader: MQTTMessageIdVariableHeader
    let payload: MQTTSubAckPayload
    
    init(fixedHeader: MQTTPacketFixedHeader =  MQTTPacketFixedHeader(messageType: .SUBACK), variableHeader: MQTTMessageIdVariableHeader, payload: MQTTSubAckPayload) {
        self.fixedHeader = fixedHeader
        self.variableHeader = variableHeader
        self.payload = payload
    }
    
    public init(messageId: Int, grantedQoSLevels: [UInt8]) {
        fixedHeader = MQTTPacketFixedHeader(messageType: .SUBACK)
        variableHeader = MQTTMessageIdVariableHeader(messageId: messageId)
        payload = MQTTSubAckPayload(grantedQoSLevels: grantedQoSLevels)
    }
    

}

public struct MQTTUnSubscribekPacket {
    let fixedHeader: MQTTPacketFixedHeader
    let variableHeader: MQTTMessageIdVariableHeader
    let payload: MQTTUnsubscribePayload
}

public struct MQTTConnAckPacket {
    var fixedHeader: MQTTPacketFixedHeader = MQTTPacketFixedHeader(messageType: .CONNACK, isDup: false, qosLevel: .AT_LEAST_ONCE, isRetain: false, remainingLength: 2)
    let variableHeader: MQTTConnAckVariableHeader
//    let payload: Data? = nil
    init(fixedHeader: MQTTPacketFixedHeader, variableHeader: MQTTConnAckVariableHeader) {
        self.fixedHeader = fixedHeader
        self.variableHeader = variableHeader
    }
    public init(returnCode: MQTTConnectReturnCode) {
        variableHeader = MQTTConnAckVariableHeader(isSessionPresent: false, connectReturnCode: returnCode)
    }
    
    public init(isSessionPresent: Bool, returnCode: MQTTConnectReturnCode) {
        variableHeader = MQTTConnAckVariableHeader(isSessionPresent: isSessionPresent, connectReturnCode: returnCode)
    }
}

public enum MQTTConnectReturnCode{
    case CONNECTION_ACCEPTED(raw: UInt8)
    case CONNECTION_REFUSED_UNACCEPTABLE_PROTOCOL_VERSION(raw: UInt8)
    case CONNECTION_REFUSED_IDENTIFIER_REJECTED(raw: UInt8)
    case CONNECTION_REFUSED_SERVER_UNAVAILABLE(raw: UInt8)
    case CONNECTION_REFUSED_BAD_USER_NAME_OR_PASSWORD(raw: UInt8)
    case CONNECTION_REFUSED_NOT_AUTHORIZED(raw: UInt8)
    case CONNECTION_OTHERS(v: UInt8)
    public init(_ raw: UInt8) {
        switch raw {
        case 0x00:
            self = .CONNECTION_ACCEPTED(raw: raw)
        case 0x01:
            self = .CONNECTION_REFUSED_UNACCEPTABLE_PROTOCOL_VERSION(raw: raw)
        case 0x02:
            self = .CONNECTION_REFUSED_IDENTIFIER_REJECTED(raw: raw)
        case 0x03:
            self = .CONNECTION_REFUSED_SERVER_UNAVAILABLE(raw: raw)
        case 0x04:
            self = .CONNECTION_REFUSED_BAD_USER_NAME_OR_PASSWORD(raw: raw)
        case 0x05:
            self = .CONNECTION_REFUSED_NOT_AUTHORIZED(raw: raw)
        default:
            self = .CONNECTION_OTHERS(v: raw)
        }
    }
    
    func rawValue() -> UInt8 {
        if case let .CONNECTION_ACCEPTED(raw) = self {
            return raw
        }
        if case let .CONNECTION_REFUSED_UNACCEPTABLE_PROTOCOL_VERSION(raw) = self {
            return raw
        }
        if case let .CONNECTION_REFUSED_IDENTIFIER_REJECTED(raw) = self {
            return raw
        }
        if case let .CONNECTION_REFUSED_SERVER_UNAVAILABLE(raw) = self {
            return raw
        }
        if case let .CONNECTION_REFUSED_BAD_USER_NAME_OR_PASSWORD(raw) = self {
            return raw
        }
        if case let .CONNECTION_REFUSED_NOT_AUTHORIZED(raw) = self {
            return raw
        }
        if case let .CONNECTION_OTHERS(raw) = self {
            return raw
        }
        return 0
    }
}

