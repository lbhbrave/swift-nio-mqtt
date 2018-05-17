//
//  MQTTPacketVariableHeader.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/5/6.
//

import Foundation

enum MQTTPacketVariableHeader {
    case CONNEC(variableHeader: MQTTConnectVariableHeader)
    case PUBLISH(variableHeader: MQTTPublishVariableHeader)
}

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

struct MQTTPublishVariableHeader {
    let topicName: String?
    let packetId: Int?
}
