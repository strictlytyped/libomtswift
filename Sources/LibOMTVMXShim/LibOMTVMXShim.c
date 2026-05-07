#include "LibOMTVMXShim.h"

#include <dlfcn.h>
#include <stddef.h>

typedef struct {
    int32_t width;
    int32_t height;
} OMTSwiftVMXSize;

typedef void *(*OMTSwiftVMXCreateFn)(OMTSwiftVMXSize dimensions, int32_t profile, int32_t colorSpace);

void *OMTSwiftVMXOpen(const char *path, int local) {
    int flags = RTLD_NOW;
    if (local) {
        flags |= RTLD_LOCAL;
    }
    return dlopen(path, flags);
}

void *OMTSwiftVMXCreate(void *handle, int32_t width, int32_t height, int32_t profile, int32_t colorSpace) {
    if (handle == NULL) {
        return NULL;
    }
    OMTSwiftVMXCreateFn create = (OMTSwiftVMXCreateFn)dlsym(handle, "VMX_Create");
    if (create == NULL) {
        return NULL;
    }
    OMTSwiftVMXSize size = { width, height };
    return create(size, profile, colorSpace);
}
