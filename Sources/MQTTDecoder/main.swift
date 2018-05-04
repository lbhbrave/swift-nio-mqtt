//
//  main.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/4/30.
//

import Foundation

let he = MQTTPacketFixedHeader(MqttMessageType: .CONNEC, isDup: true, qosLevel: .AT_LEAST_ONCE, isRetain: true, remainingLength: 4)
let vh = MQTTConnectVariableHeader(name: "f", version: 9, hasUserName: true, hasPassword: true, isWillRetain: true, willQos: true, isWillFlag: true, isCleanSession: true, keepAliveTimeSeconds: 23)
let vvvv = MQTTPackets.init(fixedHeader: he, variableHeader: vh, payloads: nil)
let v = vvvv
