//
//  Utility.m
//  MixMachDemo
//
//  Created by Dipak on 10/20/16.
//  Copyright © 2016 Deepak. All rights reserved.
//

#import "Utility.h"

/* Audio track constants */
#define AUDIO_TRACK_NAME_UNKNOWN_LANGUAGE                       @"Unknown Language"
#define AUDIO_TRACK_NAME_TRACK                                  @"Track"

@implementation Utility


/**
 * Get Audio track's full language name from language code
 */
+(NSString *)getLanguageNameFromLanguageCode:(NSString *)languageCode
{
    languageCode            = [Utility checkForNull:languageCode];
    NSLocale *englishLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];
    NSString *displayName   = [[englishLocale displayNameForKey:NSLocaleLanguageCode value:languageCode] capitalizedString];
    displayName             = [Utility checkForNull:displayName];
    
    if (!displayName || !displayName.length || [displayName isEqualToString:AUDIO_TRACK_NAME_UNKNOWN_LANGUAGE]) {
        displayName         = AUDIO_TRACK_NAME_TRACK;
    }
    return displayName;
}


+(NSString*)checkForNull:(NSString*)value
{
    if([value isKindOfClass:[NSNull class]]) {
        return @"";
    }
    else if (!value) {
        return @"";
    }
    else if (([value isKindOfClass:[NSString class]] && ([value isEqualToString:@""]))) {
        return @"";
    }
    else {
        return value;
    }
}
@end
