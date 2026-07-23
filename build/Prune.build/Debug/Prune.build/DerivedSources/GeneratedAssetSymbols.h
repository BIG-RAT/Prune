#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "magnifyingGlass" asset catalog image resource.
static NSString * const ACImageNameMagnifyingGlass AC_SWIFT_PRIVATE = @"magnifyingGlass";

/// The "radar" asset catalog image resource.
static NSString * const ACImageNameRadar AC_SWIFT_PRIVATE = @"radar";

#undef AC_SWIFT_PRIVATE
