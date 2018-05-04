//
//  MQTTUtils.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/5/4.
//

import Foundation
class MQTTUtils {
    static internal func validateFixedHeader(_ header : MQTTPacketFixedHeader) throws {
        switch header.MqttMessageType {
        case .PUBLISH, .SUBSCRIBE, .UNSUBSCRIBE:
            if header.qosLevel != .AT_LEAST_ONCE {
                throw MQTTDecodeError.invalidQosLevel
            }
        default:
            return
        }
    }
}
