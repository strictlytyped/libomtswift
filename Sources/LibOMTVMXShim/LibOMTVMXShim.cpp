#include "LibOMTVMXShim.h"

#include "vmxcodec.h"

void *OMTSwiftVMXCreate(int32_t width, int32_t height, int32_t profile, int32_t colorSpace) {
    VMX_SIZE size = { width, height };
    return VMX_Create(size, (VMX_PROFILE)profile, (VMX_COLORSPACE)colorSpace);
}

void OMTSwiftVMXDestroy(void *instance) {
    VMX_Destroy((VMX_INSTANCE *)instance);
}

void OMTSwiftVMXSetQuality(void *instance, int32_t quality) {
    VMX_SetQuality((VMX_INSTANCE *)instance, quality);
}

int32_t OMTSwiftVMXGetQuality(void *instance) {
    return VMX_GetQuality((VMX_INSTANCE *)instance);
}

int32_t OMTSwiftVMXLoadFrom(void *instance, const uint8_t *source, int32_t length) {
    return VMX_LoadFrom((VMX_INSTANCE *)instance, (BYTE *)source, length);
}

int32_t OMTSwiftVMXSaveTo(void *instance, uint8_t *destination, int32_t maxLength) {
    return VMX_SaveTo((VMX_INSTANCE *)instance, (BYTE *)destination, maxLength);
}

int32_t OMTSwiftVMXEncodeBGRA(void *instance, uint8_t *source, int32_t stride, int32_t interlaced) {
    return VMX_EncodeBGRA((VMX_INSTANCE *)instance, (BYTE *)source, stride, interlaced);
}

int32_t OMTSwiftVMXEncodeBGRX(void *instance, uint8_t *source, int32_t stride, int32_t interlaced) {
    return VMX_EncodeBGRX((VMX_INSTANCE *)instance, (BYTE *)source, stride, interlaced);
}

int32_t OMTSwiftVMXEncodeUYVY(void *instance, uint8_t *source, int32_t stride, int32_t interlaced) {
    return VMX_EncodeUYVY((VMX_INSTANCE *)instance, (BYTE *)source, stride, interlaced);
}

int32_t OMTSwiftVMXEncodeUYVA(void *instance, uint8_t *source, int32_t stride, int32_t interlaced) {
    return VMX_EncodeUYVA((VMX_INSTANCE *)instance, (BYTE *)source, stride, interlaced);
}

int32_t OMTSwiftVMXEncodeYUY2(void *instance, uint8_t *source, int32_t stride, int32_t interlaced) {
    return VMX_EncodeYUY2((VMX_INSTANCE *)instance, (BYTE *)source, stride, interlaced);
}

int32_t OMTSwiftVMXEncodeP216(void *instance, uint8_t *source, int32_t stride, int32_t interlaced) {
    return VMX_EncodeP216((VMX_INSTANCE *)instance, (BYTE *)source, stride, interlaced);
}

int32_t OMTSwiftVMXEncodePA16(void *instance, uint8_t *source, int32_t stride, int32_t interlaced) {
    return VMX_EncodePA16((VMX_INSTANCE *)instance, (BYTE *)source, stride, interlaced);
}

int32_t OMTSwiftVMXDecodeBGRA(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodeBGRA((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodeBGRX(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodeBGRX((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodeUYVY(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodeUYVY((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodeUYVA(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodeUYVA((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodeYUY2(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodeYUY2((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodeP216(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodeP216((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodePA16(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodePA16((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodePreviewBGRA(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodePreviewBGRA((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodePreviewBGRX(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodePreviewBGRX((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodePreviewUYVY(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodePreviewUYVY((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodePreviewUYVA(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodePreviewUYVA((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXDecodePreviewYUY2(void *instance, uint8_t *destination, int32_t stride) {
    return VMX_DecodePreviewYUY2((VMX_INSTANCE *)instance, (BYTE *)destination, stride);
}

int32_t OMTSwiftVMXGetEncodedPreviewLength(void *instance) {
    return VMX_GetEncodedPreviewLength((VMX_INSTANCE *)instance);
}
