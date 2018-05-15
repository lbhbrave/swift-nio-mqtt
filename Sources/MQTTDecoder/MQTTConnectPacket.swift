//
//  MQTTConnectPacket.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/5/4.
//

import Foundation
import NIO

//protocol MQTTAnyType {
//    associatedtype T
////    func wrap(_ value: MQTTAny) -> T
////    func asMQTTAny() -> MQTTAny
//}
//
//extension MQTTAnyType {
//
////    func asMQTTAny() -> MQTTAny {
////        return MQTTAny(Self.self)
////    }
//}

//struct MQTTAny {
//    fileprivate let _stroge: Any
//    init<T>(_ value: T) {
//        _stroge = value
//    }
//    func forceAs<T>(type: T.Type = T.self) -> T {
//        return (_stroge as? T)!
//    }
//}

struct MQTTConnectVariableHeader {
//    typealias T = MQTTConnectVariableHeader
    let name: String
    let version: UInt8
    let hasUserName: Bool
    let hasPassword: Bool
    let isWillRetain: Bool
    let willQos: UInt8
    let isWillFlag: Bool
    let isCleanSession: Bool
    let keepAliveTimeSeconds: UInt16
}

struct MQTTConnectPayload {
    let clientIdentifier: String
    let willTopic: String?
    let willMessage: Data?
    let userName: String?
    let password: Data?
//    init(clientIdentifier: String, willTopic: String, willMessage: String, userName: String, password: String) {
//        self.init(clientIdentifier: clientIdentifier, willTopic: willTopic, willMessage: [Character](willMessage), userName: userName, password: [Character](password))
//    }
}

struct MQTTVersion {
    let name: String
    let level: UInt8

    init(protocolName: String, protocolLevel: UInt8) throws {
        switch (protocolName, protocolLevel) {
        case ("MQTT", 4), ("MQIsdp", 3):
            name = protocolName
            level = protocolLevel
        default:
            throw MQTTDecodeError.notMatchedProtocolLevel
        }
    }
}

enum MQTTConnectReturnCode{
    case CONNECTION_ACCEPTED(raw: Int8)
    case CONNECTION_REFUSED_UNACCEPTABLE_PROTOCOL_VERSION(raw: Int8)
    case CONNECTION_REFUSED_IDENTIFIER_REJECTED(raw: Int8)
    case CONNECTION_REFUSED_SERVER_UNAVAILABLE(raw: Int8)
    case CONNECTION_REFUSED_BAD_USER_NAME_OR_PASSWORD(raw: Int8)
    case CONNECTION_REFUSED_NOT_AUTHORIZED(raw: Int8)
    case CONNECTION_OTHERS(v: Int8)
    init(_ raw: Int8) {
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
}
