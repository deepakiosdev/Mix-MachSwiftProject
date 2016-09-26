//
//  Copyright iOSDeveloperTips.com All rights reserved.
//

#import "NSString+MD5.h"
 
@interface NSString(MD5)
 
- (NSString *)MD5;

- (BOOL)containsSubString:(NSString*)subString;

- (NSString *)encodeString:(NSStringEncoding)encoding;

@end