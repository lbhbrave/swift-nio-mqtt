import NIO
import Foundation

//enum ParseError {
//    case
//}
enum ParseResult {
    case insufficientData
    case decoded(num: Int)
    case result(decoded:Int, packet: MQTTPacket)
}


fileprivate class MQTTParserState {
    internal var state: WaitingDataState = .firstByte
    internal var decoder: MQTTAbstractMessageDecoder? = nil
    
    
    internal var cumulationBuffer: ByteBuffer? = nil
    internal private(set) var curRemainlength: Int? = nil
    internal private(set) var curFixedHeader: MQTTPacketFixedHeader? = nil
    internal private(set) var curVariableHeader: MQTTPacketVariableHeader? = nil
    
    enum WaitingDataState {
        case firstByte
        case variableHeaderData
        case payloadData
    }

    func praseStep(_ buffer: inout ByteBuffer) throws -> ParseResult {
        switch self.state {
        case .firstByte:
            let (decoded, fixedheader) = try MQTTMessageDecoder.decodeFixedHeader(buffer: &buffer)
            guard decoded != 0, let fixedHeader = fixedheader else {
                return .insufficientData
            }
            
            self.decoder = MQTTMessageDecoder.newDecoder(type: fixedHeader.MqttMessageType)
            
            self.curRemainlength = fixedHeader.remainingLength
            self.curFixedHeader = fixedheader
            self.state = .variableHeaderData
            
            return .decoded(num: decoded)
            
        case .variableHeaderData:
            let (decoded, variableHeader) = try decoder!.decodeVariableHeader(fixedHeader: curFixedHeader, buffer: &buffer)
            
            guard decoded != 0 else {
                return .insufficientData
            }
            
            self.curVariableHeader = variableHeader!
            self.curRemainlength! -= decoded
            self.state = .payloadData
            return .decoded(num: decoded)

        case .payloadData:

            let (decoded, payload) = try decoder!.decodePayloads(variableHeader: self.curVariableHeader, buffer: &buffer)
            let packet = MQTTPacket(fixedHeader: self.curFixedHeader!, variableHeader: self.curVariableHeader, payloads: payload)
            
            reset()
            return .result(decoded: decoded, packet: packet)
        }
    }
    
    func reset() {
        self.curRemainlength = nil
        self.decoder = nil
        self.state = .firstByte
        self.curFixedHeader = nil
        self.curVariableHeader = nil
    }
    
    func checkIfNeedMore(buffer: ByteBuffer) -> Bool {
        if self.state == .firstByte {
            // we need to check firstByte state when parse it
            return false
        }
        switch self.state {
        case .variableHeaderData:
            if let length = caculateVariableHeaderLength() {
                return buffer.readableBytes < length
            } else {
                return true
            }
        case .payloadData:
            switch self.curFixedHeader!.MqttMessageType {
            case .PUBLISH, .CONNEC:
                return buffer.readableBytes > self.curRemainlength!
            default:
                return false
            }
        default:
            return false
        }
    }
    
    func caculateVariableHeaderLength() -> Int? {
        func decodeMsbLsb(bytes: [UInt8]) -> Int {
            let result = bytes[0] << 8 | bytes[1]
            return Int(result)
        }
        
        switch self.curFixedHeader!.MqttMessageType {
        case .CONNEC:
            return 10
        case .PUBLISH:
            guard let topicLenBytes = self.cumulationBuffer?.getBytes(at: (self.cumulationBuffer?.readerIndex)! ,length: 2) else {
                // we need to caclulate the length of publish packet's variableheader,the first two bytes
                // is the length of topic,if we cant get,means we need more data,so return max to let paraser
                // know there should be more data
                return nil
            }
            var res = 2
            res += decodeMsbLsb(bytes: topicLenBytes)
            if self.curFixedHeader!.qosLevel > .AT_LEAST_ONCE {
                res += 2
            }
            return res
        default:
            return 0
        }
    }
}

final class MQTTDecoder: ByteToMessageDecoder {
    
    typealias InboundIn = ByteBuffer
    typealias InboundOut = MQTTPacket
    private var decoding: Bool = false
    private var newDataComing: Bool = false
    
    var cumulationBuffer: ByteBuffer? {
        get {
            return self.parser.cumulationBuffer
        }
        set {
            self.parser.cumulationBuffer = newValue
        }
    }

    private var shouldKeepingParse = true
    fileprivate var parser: MQTTParserState = MQTTParserState()
    public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        
        var buffer = self.unwrapInboundIn(data)

        newDataComing = true

        guard !self.decoding else {

            self.cumulationBuffer?.write(buffer: &buffer)

            return
        }

        self.decoding = true
        
        defer {
            self.decoding = false
        }
        
        if self.cumulationBuffer == nil {
            self.cumulationBuffer = buffer
        } else {
            self.cumulationBuffer?.write(buffer: &buffer)
        }
        
        do {
            try decodeMQTT(ctx: ctx)
            if self.parser.state == .firstByte {
                // if is not the firstByte, means need more data to continue parse
                self.cumulationBuffer = nil
            }
        }
        catch {
            self.cumulationBuffer = nil
            ctx.fireErrorCaught(error)
            ctx.close(promise: nil)
        }
        
    }
    
    func decodeMQTT(ctx: ChannelHandlerContext) throws {
        // i have thinked how to write that until i read the code from official http parser
        // its write, so i follow the solution of it
        
        while newDataComing {

            newDataComing = false
            
            // we wont change bufferSlice while parseStep
            parsing: while var bufferSlice = self.parser.cumulationBuffer, bufferSlice.readableBytes > 0 {
                guard !self.parser.checkIfNeedMore(buffer: bufferSlice) else {
                    break
                }
                let res = try self.parser.praseStep(&bufferSlice)
                switch res {
                case .insufficientData:
                    
                    break parsing
                case let .decoded(decoded):
                    
                    self.cumulationBuffer?.moveReaderIndex(forwardBy: decoded)
                case let .result(decoded, packet):
                    
                    self.cumulationBuffer?.moveReaderIndex(forwardBy: decoded)
                    ctx.fireChannelRead(wrapInboundOut(packet))
                }
            }
        }
    }
    
    // will remove in the future
    func decode(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        print("decod handle")
//        continueParse: while self.shouldKeepingParse {
//            do{
//               let parseRes = try parser.praseStep(&buffer)
//                switch parseRes {
//                    case .insufficientData:
//                        return .needMoreData
//                    case let .result(packet):
//                        ctx.fireChannelRead(self.wrapInboundOut(packet))
//                default:
//                    break
//                }
//            }
//            catch {
//                self.shouldKeepingParse = false
//                ctx.close(promise: nil)
//                ctx.fireErrorCaught(error)
//            }
//        }
        return .needMoreData
    }
}
