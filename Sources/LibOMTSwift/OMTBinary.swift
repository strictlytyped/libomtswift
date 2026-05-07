import Foundation

struct OMTBinaryReader {
    private let data: Data
    private(set) var offset: Int

    init(data: Data, offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    mutating func readUInt8() throws -> UInt8 {
        guard offset + 1 <= data.count else { throw OMTError.invalidFrameLength }
        defer { offset += 1 }
        return data[offset]
    }

    mutating func readUInt16() throws -> UInt16 {
        let value: UInt16 = try readFixedWidth()
        return UInt16(littleEndian: value)
    }

    mutating func readUInt32() throws -> UInt32 {
        let value: UInt32 = try readFixedWidth()
        return UInt32(littleEndian: value)
    }

    mutating func readInt32() throws -> Int32 {
        Int32(bitPattern: try readUInt32())
    }

    mutating func readInt64() throws -> Int64 {
        let value: UInt64 = try readFixedWidth()
        return Int64(bitPattern: UInt64(littleEndian: value))
    }

    mutating func readFloat32() throws -> Float {
        Float(bitPattern: try readUInt32())
    }

    private mutating func readFixedWidth<T: FixedWidthInteger>() throws -> T {
        let byteCount = MemoryLayout<T>.size
        guard offset + byteCount <= data.count else { throw OMTError.invalidFrameLength }
        defer { offset += byteCount }
        return data.withUnsafeBytes { rawBuffer in
            rawBuffer.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
    }
}

struct OMTBinaryWriter {
    private(set) var data: Data

    init(capacity: Int = 0) {
        self.data = Data()
        self.data.reserveCapacity(capacity)
    }

    mutating func writeUInt8(_ value: UInt8) {
        data.append(value)
    }

    mutating func writeUInt16(_ value: UInt16) {
        writeFixedWidth(value.littleEndian)
    }

    mutating func writeUInt32(_ value: UInt32) {
        writeFixedWidth(value.littleEndian)
    }

    mutating func writeInt32(_ value: Int32) {
        writeUInt32(UInt32(bitPattern: value))
    }

    mutating func writeInt64(_ value: Int64) {
        writeFixedWidth(UInt64(bitPattern: value).littleEndian)
    }

    mutating func writeFloat32(_ value: Float) {
        writeUInt32(value.bitPattern)
    }

    mutating func writeData(_ value: Data) {
        data.append(value)
    }

    private mutating func writeFixedWidth<T: FixedWidthInteger>(_ value: T) {
        var mutable = value
        withUnsafeBytes(of: &mutable) { buffer in
            data.append(contentsOf: buffer)
        }
    }
}
