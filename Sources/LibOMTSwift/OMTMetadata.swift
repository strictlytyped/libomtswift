import Foundation

public enum OMTMetadataCommand {
    public static let subscribeVideo = #"<OMTSubscribe Video="true" />"#
    public static let subscribeAudio = #"<OMTSubscribe Audio="true" />"#
    public static let subscribeMetadata = #"<OMTSubscribe Metadata="true" />"#
    public static let previewVideoOn = #"<OMTSettings Preview="true" />"#
    public static let previewVideoOff = #"<OMTSettings Preview="false" />"#
    public static let suggestedQualityDefault = #"<OMTSettings Quality="Default" />"#

    public static func suggestedQuality(_ quality: OMTQuality) -> String {
        #"<OMTSettings Quality="\#(quality.metadataValue)" />"#
    }

    public static func tally(_ tally: OMTTally) -> String {
        tally.metadataXML
    }
}

struct OMTMetadataState {
    var subscriptions: OMTFrameType = []
    var tally = OMTTally()
    var preview = false
    var suggestedQuality = OMTQuality.default
    var senderInfo: OMTSenderInfo?
    var redirectAddress: String?

    mutating func process(_ xml: String) -> Bool {
        switch xml {
        case OMTMetadataCommand.subscribeVideo:
            subscriptions.insert(.video)
            return true
        case OMTMetadataCommand.subscribeAudio:
            subscriptions.insert(.audio)
            return true
        case OMTMetadataCommand.subscribeMetadata:
            subscriptions.insert(.metadata)
            return true
        case OMTMetadataCommand.previewVideoOn:
            preview = true
            return true
        case OMTMetadataCommand.previewVideoOff:
            preview = false
            return true
        default:
            break
        }

        if xml.hasPrefix("<OMTSettings"), let value = xml.omtXMLAttribute("Quality") {
            suggestedQuality = OMTQuality.metadataValue(value) ?? .default
            return true
        }

        if xml.hasPrefix("<OMTTally") {
            tally = OMTTally(
                preview: xml.omtXMLAttribute("Preview")?.lowercased() == "true",
                program: xml.omtXMLAttribute("Program")?.lowercased() == "true"
            )
            return true
        }

        if xml.hasPrefix("<OMTInfo") {
            senderInfo = OMTSenderInfo(xml: xml)
            return true
        }

        if xml.hasPrefix("<OMTRedirect") {
            redirectAddress = xml.omtXMLAttribute("Address")
            return true
        }

        return false
    }
}

extension OMTQuality {
    static func metadataValue(_ value: String) -> OMTQuality? {
        switch value {
        case "Default":
            return .default
        case "Low":
            return .low
        case "Medium":
            return .medium
        case "High":
            return .high
        default:
            return nil
        }
    }
}
