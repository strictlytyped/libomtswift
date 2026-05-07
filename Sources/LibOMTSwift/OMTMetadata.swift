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

public enum OMTMetadataConstants {
    public static let CHANNEL_SUBSCRIBE_VIDEO = OMTMetadataCommand.subscribeVideo
    public static let CHANNEL_SUBSCRIBE_AUDIO = OMTMetadataCommand.subscribeAudio
    public static let CHANNEL_SUBSCRIBE_METADATA = OMTMetadataCommand.subscribeMetadata
    public static let CHANNEL_PREVIEW_VIDEO_ON = OMTMetadataCommand.previewVideoOn
    public static let CHANNEL_PREVIEW_VIDEO_OFF = OMTMetadataCommand.previewVideoOff
    public static let TALLY_PREVIEW = #"<OMTTally Preview="true" Program="false" />"#
    public static let TALLY_PROGRAM = #"<OMTTally Preview="false" Program="true" />"#
    public static let TALLY_PREVIEWPROGRAM = #"<OMTTally Preview="true" Program="true" />"#
    public static let TALLY_NONE = #"<OMTTally Preview="false" Program="false" />"#
}

public enum OMTMetadataTemplates {
    public static let SUGGESTED_QUALITY_PREFIX = #"<OMTSettings Quality="#
    public static let SUGGESTED_QUALITY = OMTMetadataCommand.suggestedQualityDefault
    public static let SENDER_INFO_NAME = "OMTInfo"
    public static let SENDER_INFO_PREFIX = "<OMTInfo"
    public static let ADDRESS_NAME = "OMTAddress"
    public static let REDIRECT_NAME = "OMTRedirect"
    public static let REDIRECT_PREFIX = "<OMTRedirect"
}

public enum OMTMetadataUtils {
    public static func tryParse(_ xml: String) -> String? {
        xml.trimmingCharacters(in: .whitespacesAndNewlines).first == "<" ? xml : nil
    }

    public static func TryParse(_ xml: String) -> String? {
        tryParse(xml)
    }
}

public enum OMTRedirect {
    public static func toXML(_ address: String?) -> String {
        guard let address, !address.isEmpty else {
            return #"<OMTRedirect />"#
        }
        return #"<OMTRedirect Address="\#(address.omtEscapedXMLAttribute)" />"#
    }

    public static func ToXML(_ address: String?) -> String {
        toXML(address)
    }

    public static func fromXML(_ xml: String) -> String? {
        xml.omtXMLAttribute("Address")
    }

    public static func FromXML(_ xml: String) -> String? {
        fromXML(xml)
    }
}

public enum OMTMetadataFactory {
    public static func fromTally(_ tally: OMTTally) -> OMTMetadata {
        OMTMetadata(xml: OMTMetadataCommand.tally(tally))
    }

    public static func fromMediaFrame(_ metadata: OMTMediaFrame) -> OMTMetadata? {
        guard metadata.type == .metadata else { return nil }
        let xml = metadata.frameMetadata ?? OMTUtils.utf8String(from: metadata.data)
        return OMTMetadata(timestamp: metadata.timestamp, xml: xml)
    }
}

public extension OMTMetadata {
    static func fromTally(_ tally: OMTTally) -> OMTMetadata {
        OMTMetadataFactory.fromTally(tally)
    }

    static func FromTally(_ tally: OMTTally) -> OMTMetadata {
        fromTally(tally)
    }

    static func fromMediaFrame(_ metadata: OMTMediaFrame) -> OMTMetadata? {
        OMTMetadataFactory.fromMediaFrame(metadata)
    }

    static func FromMediaFrame(_ metadata: OMTMediaFrame) -> OMTMetadata? {
        fromMediaFrame(metadata)
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
