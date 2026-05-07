#ifndef LIB_OMT_VMX_SHIM_H
#define LIB_OMT_VMX_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void *OMTSwiftVMXCreate(int32_t width, int32_t height, int32_t profile, int32_t colorSpace);
void OMTSwiftVMXDestroy(void *instance);
void OMTSwiftVMXSetQuality(void *instance, int32_t quality);
int32_t OMTSwiftVMXGetQuality(void *instance);
int32_t OMTSwiftVMXLoadFrom(void *instance, const uint8_t *source, int32_t length);
int32_t OMTSwiftVMXSaveTo(void *instance, uint8_t *destination, int32_t maxLength);
int32_t OMTSwiftVMXEncodeBGRA(void *instance, uint8_t *source, int32_t stride, int32_t interlaced);
int32_t OMTSwiftVMXEncodeBGRX(void *instance, uint8_t *source, int32_t stride, int32_t interlaced);
int32_t OMTSwiftVMXEncodeUYVY(void *instance, uint8_t *source, int32_t stride, int32_t interlaced);
int32_t OMTSwiftVMXEncodeUYVA(void *instance, uint8_t *source, int32_t stride, int32_t interlaced);
int32_t OMTSwiftVMXEncodeYUY2(void *instance, uint8_t *source, int32_t stride, int32_t interlaced);
int32_t OMTSwiftVMXEncodeP216(void *instance, uint8_t *source, int32_t stride, int32_t interlaced);
int32_t OMTSwiftVMXEncodePA16(void *instance, uint8_t *source, int32_t stride, int32_t interlaced);
int32_t OMTSwiftVMXDecodeBGRA(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodeBGRX(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodeUYVY(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodeUYVA(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodeYUY2(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodeP216(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodePA16(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodePreviewBGRA(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodePreviewBGRX(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodePreviewUYVY(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodePreviewUYVA(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXDecodePreviewYUY2(void *instance, uint8_t *destination, int32_t stride);
int32_t OMTSwiftVMXGetEncodedPreviewLength(void *instance);

#ifdef __cplusplus
}
#endif

#endif
