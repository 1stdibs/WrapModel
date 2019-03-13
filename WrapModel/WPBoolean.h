//
//  WPBoolean.h
//  1stdibs
//
//  Created by Ken on 10/11/18.
//  Copyright © 2018 1stdibs. All rights reserved.
//

typedef NS_ENUM(NSInteger, WPBoolean) {
    WPBooleanNotSet,
    WPBooleanTrueVal,
    WPBooleanFalseVal,
};

WPBoolean WPBooleanFrom(BOOL boolVal);
BOOL WPBooleanIsSet(WPBoolean val);
BOOL WPBooleanIsTrue(WPBoolean val);
BOOL WPBooleanNotTrue(WPBoolean val); // NOT equivalent to WPBooleanIsFalse, rather WPBooleanNotTrue
BOOL WPBooleanIsFalse(WPBoolean val);

NSSet<NSString*>* WPTrueCharSet(void);
