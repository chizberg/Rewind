#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "cat" asset catalog image resource.
static NSString * const ACImageNameCat AC_SWIFT_PRIVATE = @"cat";

/// The "imageAnnotation" asset catalog image resource.
static NSString * const ACImageNameImageAnnotation AC_SWIFT_PRIVATE = @"imageAnnotation";

#undef AC_SWIFT_PRIVATE
