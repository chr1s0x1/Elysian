//
//  utils.h
//  Elysian
//
//  Created by chr1spwn3d on 3/2/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef utils_h
#define utils_h

#include <stdio.h>
#include <objc/runtime.h>
#import <dlfcn.h>

// I love the "let" & "var" operator
#ifndef let
#define let __auto_type const
#endif
#ifndef var
#define var __auto_type
#endif

// NSError *error;

#define ADDRISVALID(val) ((val) >= 0xffff000000000000 && (val) != 0xffffffffffffffff)
#define ASSUME_ADDR(what, val) static let what = val
#define STATIC_ADDR(what, val) static uint64_t what = val


#define ASSERT(stuff, error, text) do {\
if(stuff != true){\
LOG(error);\
SetButtonText(text);\
goto out;\
}\
} while(false)

#define _assert(condition) do {\
if(condition) {\
break;\
}\
LOG("_assert ERR: %s | %d", __FILE__, __LINE__);\
return 1;\
} while(false)

/*
 
 function : LOG
 
 Use:
 print "str" to log with any ##__VA_ARGS__
 
 */

#define LOG(str,...)\
printf(str"\n", ##__VA_ARGS__)


/*
 
 function : fileExists
 
 Use:
 check if "file" exists at "fileExistsAtPath(file)"
 
 */


#define fileExists(file) [[NSFileManager defaultManager] fileExistsAtPath:@(file)]



/*
 
 function : removeFile
 
 Use:
 delete "file" at "removeItemAtPath(file)"
 
 */

#define removeFile(file) if (fileExists(file)) {\
[[NSFileManager defaultManager]  removeItemAtPath:@(file) error:&error]; \
if (error) { \
LOG("[-] Error: removing file %s (%s)", file, [[error localizedDescription] UTF8String]); \
error = NULL; \
}\
}



/*
 
 function : copyFile
 
 Use:
 copy a file from "copyFrom" to "copyTo"
 
 */

#define copyFile(copyFrom, copyTo) [[NSFileManager defaultManager] copyItemAtPath:@(copyFrom) toPath:@(copyTo) error:&error]; \
if (error) { \
LOG("[-] Error copying item %s to path %s (%s)", copyFrom, copyTo, [[error localizedDescription] UTF8String]); \
error = NULL; \
}



/*
 
 function : moveFile
 
 Use:
 move a file from "copyFrom" to "moveTo"
 
 */

#define moveFile(copyFrom, moveTo) [[NSFileManager defaultManager] moveItemAtPath:@(copyFrom) toPath:@(moveTo) error:&error]; \
if (error) {\
LOG("[-] Error moviing item %s to path %s (%s)", copyFrom, moveTo, [[error localizedDescription] UTF8String]); \
error = NULL; \
}



/*
 
 function : createFile
 
 Use:
 create a file at "where" which will contain "info"
 
 */

#define createFILE(where, info) {\
    [[NSFileManager defaultManager] createFileAtPath:@(where) contents:info attributes:nil];\
    if(!fileExists(where)) {\
        LOG("ERR: Failed to create file at %s", where);\
    }\
}

#define in_bundle(obj) strdup([[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@obj] UTF8String])
#endif /* utils_h */

