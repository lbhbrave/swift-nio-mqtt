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

struct MQTTPublishVariableHeader {
    
}
