//
//  NSData+HexData.m
//  TBScope
//
//  Created by Frankie Myers on 4/15/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "NSData+HexData.h"

@implementation NSData (HexData)

+ (NSData *)dataFromHexString:(NSString *)string
{
    NSMutableData *stringData = [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < [string length] / 2; i++) {
        byte_chars[0] = [string characterAtIndex:i*2];
        byte_chars[1] = [string characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [stringData appendBytes:&whole_byte length:1];
    }
    return stringData;
}

- (NSString*)hexStringRepresentation
{
    unichar* hexChars = (unichar*)malloc(sizeof(unichar) * (self.length*2));
    unsigned char* bytes = (unsigned char*)self.bytes;
    for (NSUInteger i = 0; i < self.length; i++) {
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
}
@end
