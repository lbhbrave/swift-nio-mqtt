import NIO
import Foundation

//enum ParseError {
//    case
//}
enum ParseResult {
    case insufficientData
    case continueParsing
    case parseError(Error)
    case result(MQTTPacket)
}

// TODO payloads的解析该怎么设计？？

// praseStep怎么设计才能代码复用

fileprivate struct MQTTParserState {
    internal var state: WaitingDataState = .firstByte
    internal var decoder: MQTTAbstractMessageDecoder? = nil
    
    internal private(set) var curRemainlength: Int? = nil
    internal private(set) var curFixedHeader: MQTTPacketFixedHeader? = nil
    internal private(set) var curVariableHeader: MQTTPacketVariableHeader? = nil

    
    enum WaitingDataState {
        case firstByte
        case variableHeaderData
        case payloadData
    }
    
    
    mutating func praseStep(_ buffer: inout ByteBuffer) throws -> ParseResult {

        
        switch self.state {
        case .firstByte:
            guard let byte = buffer.readInteger(as: UInt8.self) else {
                return .insufficientData
            }
            if self.decoder == nil {
                let messageType = try MQTTMessageDecoder.decodeMessageType(type: byte)
                self.decoder = MQTTMessageDecoder.newDecoder(type: messageType)
            }
            
            let (needMoredata, fixedheader) = try self.decoder!.decodeFixedHeader(firstByte: byte, buffer: &buffer)
            
            if needMoredata {
                return .insufficientData
            }
            
            assert(fixedheader != nil)
        
            self.curRemainlength = fixedheader!.remainingLength
            self.curFixedHeader = fixedheader!
            self.state = .variableHeaderData
            
            return .continueParsing
            
        case .variableHeaderData:
            let curIndex = buffer.readerIndex
            let (needMoreData, variableHeader) = try decoder!.decodeVariableHeader(buffer: &buffer)
            
            if needMoreData {
                return .insufficientData
            }

            self.curVariableHeader = variableHeader!
            self.curRemainlength! -= (buffer.readerIndex - curIndex)
            self.state = .payloadData
            
            return .continueParsing

        case .payloadData:
            if self.curRemainlength! > buffer.readableBytes {
                return .insufficientData
            }
            
            if self.curRemainlength! < buffer.readableBytes {
                throw MQTTDecodeError.invalidPayloadBytes
            }

            let (_, payload) = try decoder!.decodePayloads(variableHeader: self.curVariableHeader, buffer: &buffer)
            let packet = MQTTPacket(fixedHeader: self.curFixedHeader!, variableHeader: self.curVariableHeader, payloads: payload)
            reset()

            return .result(packet)
        }
    }
    
    mutating func reset() {
        self.curRemainlength = nil
        self.decoder = nil
        self.state = .firstByte
        self.curFixedHeader = nil
        self.curVariableHeader = nil
    }
}


class MQTTDecoder: ByteToMessageDecoder {
    var cumulationBuffer: ByteBuffer?
    fileprivate var parser: MQTTParserState = MQTTParserState()
    func decode(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
    
        repeat {
            _ = try parser.praseStep(&buffer)
//            switch retult {
//            case .parseError(let error)
//
//            }
            
        } while true
        
        return .continue
    }
    
    
}
