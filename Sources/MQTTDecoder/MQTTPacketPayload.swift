//
//  MQTTPacketPayload.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/5/6.
//

import Foundation
enum MQTTPacketPayload {
    case CONNEC(payload: MQTTConnectPayload)
}
