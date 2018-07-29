//
//  MQTTMessageEncoder.swift
//  MQTTDecoder
//
//  Created by yh on 2018/7/29.
//

import Foundation

class MQTTMessageEncoder {
    static func encodeVariableLength (variableHeader: MQTTPacketVariableHeader) throws -> Int {
        switch variableHeader {
        case .CONNACK(variableHeader: _):
            return 2
        default:
            return 0
        }
    }
}
