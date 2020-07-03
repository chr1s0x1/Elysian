//
//  ViewController.h
//  Elysian
//
//  Created by chr1spwn3d on 3/2/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <UIKit/UIKit.h>


#define MESSAGE(msg, shouldwait) ALERT(@msg, shouldwait)

static inline void ALERT(NSString *notice, Boolean wait) {
 dispatch_semaphore_t semaphore;
 if (wait)
 semaphore = dispatch_semaphore_create(0);
 dispatch_async(dispatch_get_main_queue(), ^{
     UIAlertController *alertvc = [UIAlertController alertControllerWithTitle:@"Elysian Says:" message:notice preferredStyle:UIAlertControllerStyleAlert];
     UIAlertAction *YEP = [UIAlertAction actionWithTitle:@"Gotcha" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
         if(wait)
         dispatch_semaphore_signal(semaphore);
     }];
    [alertvc addAction:YEP];
    [alertvc setPreferredAction:YEP];
    [[[[[UIApplication sharedApplication] delegate] window] rootViewController] presentViewController:alertvc animated:YES completion:nil];
 });
    if (wait)
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

@interface ViewController : UIViewController {
    
    IBOutlet UIButton *JBButton;
    
}

@end

