//
//  amfidestroyer.h
//  Elysian
//
//  Created by chris  on 5/20/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef amfidestroyer_h
#define amfidestroyer_h

/*
 function: find_amfid
 
 Use:
 Grabs the amfi pid for use in amfidestroyer()
 */
int find_amfid(void);

/*
 function: hijacksysdiagnose
 
 Use:
 borrows/steals the sysdiagnose creds to get the amfid task port
 */
bool hijacksysdiagnose(void);

/*
 function: amfidestroyer
 
 Use:
 Patches amfid so we can run fakesigned binaries
 */
int amfidestroyer(void);
#endif /* amfidestroyer_h */
