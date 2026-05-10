# libomtswift

Native Swift implementation of the [Open Media Transport](https://openmediatransport.org) (OMT) network protocol for macOS and iOS.

## What is included

- `OMTSender` and `OMTReceiver` built on `Network.framework`.
- Callback and `AsyncStream` receive APIs.
- Bonjour discovery for `_omt._tcp.` services and helpers for OMT names, URLs, and address XML.
- OMT binary frame encode/decode, including attached video/audio metadata and preview payloads.
- Metadata helpers for subscriptions, preview mode, tally, sender information, redirects, and suggested quality.
- Sender and receiver control helpers for tally, quality, redirects, connection metadata, sender information, and statistics.
- VMX1 video encode/decode through the local `LibVMX.xcframework` and C++ shim.
- FPA1 planar float audio compaction/expansion.
- Utility helpers for frame-rate conversion, UTF-8 metadata, planar audio conversion, timestamps, preview sizing, and PSNR calculation.

## Usage

```swift
import LibOMTSwift

let discovery = OMTDiscovery.shared
discovery.onUpdate = { sources in
    print(sources.map(\.fullName))
}
discovery.start()

let receiver = try OMTReceiver(
    url: "omt://camera.local:6400",
    frameTypes: [.video, .audio, .metadata],
    preferredVideoFormat: .uyvyOrBGRA,
    flags: []
)

receiver.onFrame = { frame in
    switch frame.type {
    case .video:
        print("video", frame.width, frame.height, frame.codec)
    case .audio:
        print("audio", frame.channels, frame.samplesPerChannel)
    case .metadata:
        print(frame.frameMetadata ?? "")
    default:
        break
    }
}
```

`OMTSender` accepts raw UYVY/YUY2/BGRA/UYVA/P216/PA16 frames and encodes them to VMX1 before transport. If the frame is already `.vmx1`, it is sent as-is.

Set an `OMTMediaFrame` timestamp to `-1` to have the sender fill it from `OMTClock`.

## VMX linking

The Swift package links VMX through `LibVMX`, a binary target expected at:

```text
../libvmx/build/LibVMX.xcframework
```

Build or provide that XCFramework before building `libomtswift`. `LibOMTVMXShim` is a C++ target that wraps the VMX C++ headers in a Swift-friendly C ABI.
