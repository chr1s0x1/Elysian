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

#define LOG(str)\
printf(str)

#define LOGM(str, more)\
printf(str, more)

#define fileExists(file) [[NSFileManager defaultManager] fileExistsAtPath:@(file)]


#define removeFile(file) if (fileExists(file)) {\
[[NSFileManager defaultManager]  removeItemAtPath:@(file) error:&error]; \
if (error) { \
LOG("[-] Error: removing file %s (%s)", file, [[error localizedDescription] UTF8String]); \
error = NULL; \
}\
}


#define copyFile(copyFrom, copyTo) [[NSFileManager defaultManager] copyItemAtPath:@(copyFrom) toPath:@(copyTo) error:&error]; \
if (error) { \
LOG("[-] Error copying item %s to path %s (%s)", copyFrom, copyTo, [[error localizedDescription] UTF8String]); \
error = NULL; \
}


#define moveFile(copyFrom, moveTo) [[NSFileManager defaultManager] moveItemAtPath:@(copyFrom) toPath:@(moveTo) error:&error]; \
if (error) {\
LOG("[-] Error moviing item %s to path %s (%s)", copyFrom, moveTo, [[error localizedDescription] UTF8String]); \
error = NULL; \
}

void createFILE(const char *where, NSData *info) {
    [[NSFileManager defaultManager] createFileAtPath:@(where) contents:info attributes:nil];
    if(!fileExists(where)) {
        LOG("[-] File create failed \n");
        return;
    }
}

#endif /* utils_h */
