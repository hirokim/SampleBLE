//
//  BLEScanner.h
//  BLESample
//
//  Created by Hiroki Matsuse on 2014/11/27.
//  Copyright (c) 2014年 Hiroki Matsuse. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface BLEScanner : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic) CBCentralManager *centralManager;
@property (nonatomic) NSMutableSet *peripherals;
@property (nonatomic, readonly) BOOL isScanning;

+ (instancetype)sharedInstance;

@end
