//
//  StreamingModule.c
//  RNAudio
//
//  Created by JeungminOh on 30/05/2017.
//  Copyright © 2017 Joshua Sierles. All rights reserved.
//

#import "StreamingModule.h"

@implementation StreamingModule

- (void)prepare:(void(^)(AVAudioPCMBuffer *))handler {
    _completionHandler = [handler copy];
    
    engine = [[AVAudioEngine alloc] init];
    
    AVAudioInputNode *input = [engine inputNode];
    AVAudioFormat *format = [input outputFormatForBus: 0];
    [input installTapOnBus: 0 bufferSize: 8192 format: format block: ^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
        // ‘buf' contains audio captured from input node at time 'when'
        _completionHandler(buf);
    }];
}

- (void)start {
    NSError *error = nil;
    NSLog(@"%@", [engine inputNode]);
    
    if (![engine startAndReturnError:&error]) {
        NSLog(@"engine failed to start: %@", error);
        return;
    }
}

- (void)pause {
    // AVAudioInputNode *input = [engine inputNode];
    // [input removeTapOnBus: 0];
    [engine pause];
}

@end
