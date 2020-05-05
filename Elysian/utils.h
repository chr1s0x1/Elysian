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

// I love the "let" & "var" operator
#ifndef let
#define let __auto_type const
#endif
#ifndef var
#define var __auto_type
#endif

#define ADDRISVALID(val) ((val) >= 0xffff000000000000 && (val) != 0xffffffffffffffff)

#define ASSERT(stuff, error) do {\
if(stuff){\
break;\
}else{\
LOG(error);\
goto out;\
}\
} while(false)


#define ASSERTM(stuff, error, more) do {\
if(stuff){\
break;\
}else{\
LOG(error);\
more;\
goto out;\
}\
} while(false)

/*
 
 function : LOG
 
 Use:
 print "str" to log
 
 */

#define LOG(str)\
printf(str)



/*
 
 function : LOGM (Log (M)ore)
 
 Use:
 Log "str" with additional info "more"
 */

#define LOGM(str, more)\
printf(str, more)



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
        LOGM("ERR: Failed to create File at %s \n", where);\
        return;\
    }\
}

#endif /* utils_h */
