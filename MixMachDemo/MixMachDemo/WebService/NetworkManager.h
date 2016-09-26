//
//  NetworkManager.h
//  MixMachDemo
//
//  Created by dipak on 9/26/16.
//  Copyright © 2016 Deepak. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void (^CompletionHandler)(id receivedObj, NSUInteger errorCode);
typedef void (^ProgressHandler)(CGFloat progressValue);
typedef void (^downloadedData)(NSData* data);

@interface NetworkManager : NSObject

@end
