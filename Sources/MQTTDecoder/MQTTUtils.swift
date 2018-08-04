//
//  MQTTUtils.swift
//  MQTTDecoder
//
//  Created by yanghuan on 2018/5/4.
//

import Foundation
class MQTTUtils {
    typealias MQTTVersion = (name: String, level: UInt8)
    
    
    static internal func validateFixedHeader(_ header : MQTTPacketFixedHeader, firstByte: UInt8) throws {
        switch header.messageType {
        case .PUBREL, .SUBSCRIBE, .UNSUBSCRIBE:
            if header.qosLevel != .AT_LEAST_ONCE {
                throw MQTTDecodeError.invalidQosLevel
            }
            if header.messageType == .UNSUBSCRIBE {
                guard firstByte & UInt8(0x0F) == 0x02 else {
                    throw MQTTDecodeError.invalidFixedHeader(Str: "subscribe first byte invaliad")
                }
            }
        default:
            return
        }
    }
   
//    static internal func validateConnecPwordAndUnameFlag(pwordFlag: Bool, unameFlag: Bool) throws {
//        if !unameFlag && pwordFlag {
//            throw MQTTDecodeError.invalidVariableHeader(str: "password flag should be 0 when username flag is 0")
//        }
//    }
    
    static internal func validateProtocolNameAndLevel(version: MQTTVersion) throws {
        switch version {
        case ("MQTT", 4), ("MQIsdp", 3):
            return
        default:
            throw MQTTDecodeError.notMatchedProtocolLevel
        }
    }
    
    static internal func validateMessageId(id: Int) throws {
//        if id == 0 {
//            throw MQTTDecodeError.invalidClientId
//        }
    }
    
    static internal func validateClientIdentifier(version: MQTTVersion, clientId: String?) throws {
        let MIN_CLIENT_ID_LENGTH = 1;
        let MAX_CLIENT_ID_LENGTH = 23;
        
        switch version {
        case ("MQTT", 4):
            if clientId == nil {
                 throw MQTTDecodeError.invalidClientId
            }
        case ("MQIsdp", 3):
            if clientId == nil ||
                clientId!.utf8.count < MIN_CLIENT_ID_LENGTH ||
                clientId!.utf8.count > MAX_CLIENT_ID_LENGTH {
                throw MQTTDecodeError.invalidClientId
            }
        default:
            throw MQTTDecodeError.notMatchedProtocolLevel
        }
    }
}

internal func > (lhs: Int, rhs: UInt32) -> Bool {
    return lhs > Int(rhs)
}

