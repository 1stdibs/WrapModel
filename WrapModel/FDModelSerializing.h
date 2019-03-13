//
//  FDModelSerializing.h
//  1stdibs
//
//  Created by Ken Worley on 9/10/18.
//  Copyright © 2018 1stdibs. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FDModelSerializing <NSObject>

// Initialize model with dictionary converted from JSON
-(nonnull instancetype)initWithJSONDictionary:(nonnull NSDictionary*)jsonDictionary
                                      mutable:(BOOL)mutable;

// Dictionary representation of model suitable for converting back to JSON (for posting).
-(nonnull NSDictionary*)JSONDictionaryWithoutNulls:(BOOL)withoutNulls;

@end
