#ifndef LIB_OMT_VMX_SHIM_H
#define LIB_OMT_VMX_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void *OMTSwiftVMXOpen(const char *path, int local);
void *OMTSwiftVMXCreate(void *handle, int32_t width, int32_t height, int32_t profile, int32_t colorSpace);

#ifdef __cplusplus
}
#endif

#endif
