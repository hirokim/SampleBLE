//
//  BLEScanner.m
//  BLESample
//
//  Created by Hiroki Matsuse on 2014/11/27.
//  Copyright (c) 2014年 Hiroki Matsuse. All rights reserved.
//

#import "BLEScanner.h"

#define CBCentralManagerSerialQueueName "CBCentralManager.SerialQueue"
#define AdvertisementDataLocalName @"SampleDevice"
#define ServiceUUID @"ffe0"
// #define CBScannerAllowDuplicates

@interface BLEScanner ()

@property (nonatomic) BOOL isScanning;

@end

@implementation BLEScanner

static dispatch_queue_t serialQueue;

+ (instancetype)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        // 専用のキューでスキャンする
        serialQueue = dispatch_queue_create(CBCentralManagerSerialQueueName, NULL);
        
        // セントラル生成
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:serialQueue];
        
        // ペリフェラル格納用
        self.peripherals = [[NSMutableSet alloc] init];
    }
    return self;
}

#pragma mark - CBCentralManagerDelegate

/**
 * 端末のBLEの状態変化
 *
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"%s", __FUNCTION__);
    
    [self logState];
    
    //BLEの状態が変化し、使用可能な状態になった
    if([self isBLEAvailable]) {
        [self startScan];
    }
}

/**
 * ペリフェラルが見つかった
 *
 */
- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSLog(@"%s", __FUNCTION__);
    
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    if ([localName length] && [localName rangeOfString:AdvertisementDataLocalName].location != NSNotFound) {
        
        // Scan を停止させる
        [self.centralManager stopScan];
        self.isScanning = NO;
        
        // CBPeripheral のインスタンスを保持しなければならない
        [self.peripherals addObject:peripheral];
        
        // 見つかったペリフェラルに接続開始（バックグラウンドで動作する場合はオプションを指定）
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

/**
 * ペリフェラルに接続した
 *
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"%s", __FUNCTION__);
    
    // ペリフェラルの中のサービスを探す。
    peripheral.delegate = self;
    [peripheral discoverServices:@[[CBUUID UUIDWithString:ServiceUUID]]];
}

/**
 * ペリフェラルに接続失敗
 *
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%s", __FUNCTION__);
}

/**
 * ペリフェラルの接続が切れた
 *
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%s", __FUNCTION__);
}

#pragma mark - CBPeripheralDelegate

/**
 * ペリフェラルの中からサービスが見つかった
 *
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"%s", __FUNCTION__);
    
    // キャラクタリスティックを全て探す
    for (CBService * service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

/**
 * サービスの中からキャラクタリスティックが見つかった
 *
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"%s", __FUNCTION__);
    
    UIImage *image = [[UIImage alloc] init];
    
    // キャラクタリスティックに対して各種設定
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        // 画像データ設定
        [peripheral writeValue:[NSData dataWithData:UIImageJPEGRepresentation(image, 1.0)]
             forCharacteristic:characteristic
                          type:CBCharacteristicWriteWithoutResponse];
    }
}

/**
 * データを書き込んだ結果
 *
 */
- (void)peripheral:(CBPeripheral *)peripheral
                  :(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"%s", __FUNCTION__);
}

#pragma mark - My function

/**
 * ログ出力
 *
 */
- (void)logState {
    if (self.centralManager.state == CBCentralManagerStateUnsupported) {
        NSLog(@"The platform/hardware doesn't support Bluetooth Low Energy.");
    }
    else if (self.centralManager.state == CBCentralManagerStateUnauthorized) {
        NSLog(@"The app is not authorized to use Bluetooth Low Energy.");
    }
    else if (self.centralManager.state == CBCentralManagerStatePoweredOff) {
        NSLog(@"Bluetooth is currently powered off.");
    }
    else if (self.centralManager.state == CBCentralManagerStateResetting) {
        NSLog(@"Bluetooth is currently resetting.");
    }
    else if (self.centralManager.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"Bluetooth is currently powered on.");
    }
    else if (self.centralManager.state == CBCentralManagerStateUnknown) {
        NSLog(@"Bluetooth is an unknown status.");
    }
    else {
        NSLog(@"Unknown status code.");
    }
}

/**
 * BLEが使える状態かどうかチェックする
 *
 */
- (BOOL)isBLEAvailable {
    return (self.centralManager.state == CBCentralManagerStatePoweredOn);
}

/**
 * ペリフェラルのスキャン開始
 *
 */
- (void)startScan
{
    NSLog(@"%s", __FUNCTION__);
    
    if (self.isScanning) {
        return;
    }
    
    self.isScanning = YES;
    
#ifdef CBScannerAllowDuplicates
    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
#else
    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
#endif
    
    // AdvertiseにService情報を載せてくれるならnilではなくサービスを指定する（例：@[[CBUUID UUIDWithString:@"FF01"]]）
    [self.centralManager scanForPeripheralsWithServices:nil options:options];
}

/**
 * 指定したペリフェラルから指定されたUUIDのサービスを検索
 *
 */
-(CBService *) findServiceFromUUID:(CBUUID *)UUID peripheral:(CBPeripheral *)aPeripheral {
    
    for(int i = 0; i < aPeripheral.services.count; i++) {
        
        CBService *service = [aPeripheral.services objectAtIndex:i];
        NSLog(@"CBService %@",[service UUID]);
        if ([UUID isEqual:service.UUID]) return service;
    }
    return nil;
}

/**
 * 指定したサービスから指定されたUUIDのキャラクタリスティックを検索
 *
 */
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service {
    
    for(int i=0; i < service.characteristics.count; i++) {
        
        CBCharacteristic *characteristic = [service.characteristics objectAtIndex:i];
        NSLog(@"CBCharacteristic %@",[characteristic UUID]);
        if ([UUID isEqual:characteristic.UUID]) return characteristic;
    }
    return nil;
}

@end
