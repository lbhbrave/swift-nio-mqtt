//
//  MQTTProtocolError.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/4/30.
//

import Foundation
//enum MQTTDecodeError: Error {
//    case serverError
//
//    init(errorCode: UInt16) {
//        switch errorCode {
//        case 1000:
//            self = .serverError
//        default:
//            self = .serverError
//        }
//    }
//}
public enum MQTTDecodeError: Error {
    case remainLengthExceed
    case invalidPayloadBytes
    case invalidMessageType
    case invalidQosLevel
    case invalidVersion
    case exceedMaxStringLength
    case invalidProtocolName
    case notMatchedProtocolLevel
    case invalidVariableHeader(Str: String)
    case invalidClientId
    case unknown
}
