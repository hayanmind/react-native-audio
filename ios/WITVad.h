//
//  WITVad.h
//  Wit
//
//  Created by Aric Lasry on 8/6/14.
//  Copyright (c) 2014 Willy Blandin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import "WITCvad.h"

@protocol WITVadDelegate;

@interface WITVad : NSObject

@property (nonatomic, weak) id<WITVadDelegate> delegate;

@property (nonatomic, assign) BOOL stoppedUsingVad;

- (instancetype)initWithAudioSampleRate:(int)audioSampleRate vadSensitivity:(int)_vadSensitivity vadTimeout:(int)_vadTimeout;
- (void)gotAudioSamples:(NSData *)samples;

@end


@protocol WITVadDelegate <NSObject>

-(void) vadStartedTalking;
-(void) vadStoppedTalking;

@end
