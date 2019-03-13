//
//  WPBoolean.m
//  1stdibs
//
//  Created by Ken Worley on 10/11/18.
//  Copyright © 2018 1stdibs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPBoolean.h"

WPBoolean WPBooleanFrom(BOOL boolVal) {
    return boolVal ? WPBooleanTrueVal : WPBooleanFalseVal;
}

BOOL WPBooleanIsSet(WPBoolean val) {
    return val != WPBooleanNotSet;
}

BOOL WPBooleanIsTrue(WPBoolean val) {
    return val == WPBooleanTrueVal;
}

BOOL WPBooleanNotTrue(WPBoolean val) {
    return val != WPBooleanTrueVal;
}

BOOL WPBooleanIsFalse(WPBoolean val) {
    return val == WPBooleanFalseVal;
}

NSSet<NSString*>* WPTrueCharSet() {
    static dispatch_once_t onceToken;
    static NSSet* charSet;
    dispatch_once(&onceToken, ^{
        charSet = [NSSet setWithArray:@[@"t", @"T", @"y", @"Y", @"1"]];
    });
    return charSet;
}
