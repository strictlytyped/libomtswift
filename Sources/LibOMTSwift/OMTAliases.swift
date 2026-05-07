public typealias OMTSend = OMTSender
public typealias OMTReceive = OMTReceiver

public protocol OMTBase: AnyObject {
    func close()
}

public protocol OMTSendReceiveBase: AnyObject {
    func getVideoStatistics() -> OMTStatistics
    func getAudioStatistics() -> OMTStatistics
}

extension OMTSender: OMTBase, OMTSendReceiveBase {}
extension OMTReceiver: OMTBase, OMTSendReceiveBase {}
