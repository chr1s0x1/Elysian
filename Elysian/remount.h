//
//  remount.h
//  Elysian
//
//  Created by chris  on 4/1/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef remount_h
#define remount_h

#import "offsets.h"

// remount returns
enum remount_ret {
    _NOLAUNCHDERR,
    _RENAMEDSNAP,
    _NOSNAPS,
};

// remount for ios 13
int remountFS(void);
bool renameSnapRequired(void);
#endif /* remount_h */

