//
//  Copyright iOSDeveloperTips.com All rights reserved.
//

#import <CommonCrypto/CommonCrypto.h>
 
@implementation NSData(MD5)

static inline char itoh(int i) {
    if (i > 9) return 'A' + (i - 10);
    return '0' + i;
}

- (NSString*)MD5
{
 	// Create byte array of unsigned chars
  unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];

	// Create 16 byte MD5 hash value, store in buffer
  CC_MD5(self.bytes, (CC_LONG)self.length, md5Buffer);
    
	// Convert unsigned char buffer to NSString of hex values
  NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
  for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) 
		[output appendFormat:@"%02x",md5Buffer[i]];

  return output;
}


- (NSData *)encryptDataWithKey:(NSString *)key {
    return [self AES128Operation:kCCEncrypt andKey:key mode:NO];
}

- (NSData *)decryptDataWithKey:(NSString *)key {
    return [self AES128Operation:kCCDecrypt andKey:key mode:NO];
}

- (NSData *)decryptDataWithKey:(NSString *)key mode:(BOOL)isECB {
    return [self AES128Operation:kCCDecrypt andKey:key mode:isECB];
}

-(NSString*)hexRepresentationWithSpaces_AS:(BOOL)spaces
{
    const unsigned char* bytes = (const unsigned char*)[self bytes];
    NSUInteger nbBytes = [self length];
    //If spaces is true, insert a space every this many input bytes (twice this many output characters).
    static const NSUInteger spaceEveryThisManyBytes = 4UL;
    //If spaces is true, insert a line-break instead of a space every this many spaces.
    static const NSUInteger lineBreakEveryThisManySpaces = 4UL;
    const NSUInteger lineBreakEveryThisManyBytes = spaceEveryThisManyBytes * lineBreakEveryThisManySpaces;
    NSUInteger strLen = 2*nbBytes + (spaces ? nbBytes/spaceEveryThisManyBytes : 0);
    
    NSMutableString* hex = [[NSMutableString alloc] initWithCapacity:strLen];
    for(NSUInteger i=0; i<nbBytes; ) {
        [hex appendFormat:@"%02X", bytes[i]];
        //We need to increment here so that the every-n-bytes computations are right.
        ++i;
        
        if (spaces) {
            if (i % lineBreakEveryThisManyBytes == 0) [hex appendString:@"\n"];
            else if (i % spaceEveryThisManyBytes == 0) [hex appendString:@" "];
        }
    }
    
    return hex;
}

-(NSString *)NSDataToHex
{
    NSUInteger i, len;
    unsigned char *buf, *bytes;
    
    len = self.length;
    bytes = (unsigned char*)self.bytes;
    buf = malloc(len*2);
    
    for (i=0; i < len; i++)
    {
        buf[i*2] = itoh((bytes[i] >> 4) & 0xF);
        buf[i*2+1] = itoh(bytes[i] & 0xF);
    }
    
    return [[NSString alloc] initWithBytesNoCopy:buf length:len*2 encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

- (NSString*)stringWithHexBytes
{
    unichar* hexChars = (unichar*)malloc(sizeof(unichar) * (self.length*2));
    unsigned char* bytes = (unsigned char*)self.bytes;
    for (NSUInteger i = 0; i < self.length; i++)
    {
        unichar c = bytes[i] / 16;
        if (c < 10) c += '0';
        else c += 'a' - 10;
        hexChars[i*2] = c;
        c = bytes[i] % 16;
        if (c < 10) c += '0';
        else c += 'a' - 10;
        hexChars[i*2+1] = c;
    }
    
    NSString* retVal = [[NSString alloc] initWithCharactersNoCopy:hexChars
                                                           length:self.length*2
                                                     freeWhenDone:YES];
    
    return retVal;
    
    /*NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:([self length] * 2)];
    const unsigned char *dataBuffer = [self bytes];
    int i;
    for (i = 0; i < [self length]; ++i) {
        [stringBuffer appendFormat:@"%02lX", (unsigned long)dataBuffer[i]];
    }
    return stringBuffer;*/
}

-(NSData*)AES128Operation:(CCOperation)operation andKey:(NSString*)key mode:(BOOL)isECB
{
    char keyPtr[kCCKeySizeAES256+1];
    bzero( keyPtr, sizeof( keyPtr ) );
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof( keyPtr ) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc( bufferSize );
    
    uint32_t mode = kCCOptionPKCS7Padding;
    if(isECB) {
        mode = kCCOptionECBMode;
    }
    
    size_t numBytesDecrypted = 0;
    
    CCCryptorStatus cryptStatus = CCCrypt(operation, kCCAlgorithmAES128, mode,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesDecrypted );
    
    if( cryptStatus == kCCSuccess ) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
        
    }
    
    free( buffer );
    return nil;
}

@end
