# libomtswift

Native Swift implementation of the [Open Media Transport](https://openmediatransport.org) (OMT) network protocol for macOS and iOS.

## What is included

- `OMTSender` and `OMTReceiver` built on `Network.framework`.
- Bonjour discovery for `_omt._tcp.` services.
- OMT binary frame encode/decode, including attached video/audio metadata.
- Metadata controls for subscriptions, preview mode, tally, sender information, redirects, and suggested quality.
- VMX1 video encode/decode through `libvmx` symbols already linked into the process.
- FPA1 planar float audio compaction/expansion.

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

## VMX linking

The Swift package does not hard-link `libvmx`; it resolves `VMX_*` symbols dynamically from the process by default. If needed, pass `.path(...)` to `OMTSender` or `OMTReceiver` to load a specific library image.
