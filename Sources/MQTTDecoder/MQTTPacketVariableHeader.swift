//
//  MQTTPacketVariableHeader.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/5/6.
//

import Foundation

// TODO 使用emnm来控制类型。加油！
enum MQTTPacketVariableHeader {
    case CONNEC(variableHeader: MQTTConnectVariableHeader)
    case PUBLISH(variableHeader: MQTTPublishVariableHeader)
}

struct MQTTPublishVariableHeader {
    
}
