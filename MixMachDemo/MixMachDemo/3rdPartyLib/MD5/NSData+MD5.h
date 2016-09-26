//
//  Copyright iOSDeveloperTips.com All rights reserved.
//

#import "NSData+MD5.h"
 
@interface NSData(MD5)
 
- (NSString *)MD5;
- (NSData *)encryptDataWithKey:(NSString *)key;
- (NSData *)decryptDataWithKey:(NSString *)key;
- (NSData *)decryptDataWithKey:(NSString *)key mode:(BOOL)isECB;
- (NSString*)stringWithHexBytes;
-(NSString *)NSDataToHex;
-(NSString*)hexRepresentationWithSpaces_AS:(BOOL)spaces;

@end