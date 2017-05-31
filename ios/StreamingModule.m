//
//  StreamingModule.c
//  RNAudio
//
//  Created by JeungminOh on 30/05/2017.
//  Copyright © 2017 Joshua Sierles. All rights reserved.
//

#import "StreamingModule.h"

@implementation StreamingModule

- (void)prepare:(NSURL *)recordingFileUrl handler:(void(^)(AVAudioPCMBuffer *))handler {
    _completionHandler = [handler copy];
    fileUrl = recordingFileUrl;
    
    engine = [[AVAudioEngine alloc] init];
    
    AVAudioInputNode *input = [engine inputNode];
    AVAudioFormat *format = [input outputFormatForBus: 0];
    
    NSError *error = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForWriting:fileUrl
                                                   settings:format.settings
                                                      error:&error];
    
    [input installTapOnBus: 0 bufferSize: 8192 format: format block: ^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
        // ‘buf' contains audio captured from input node at time 'when'
        _completionHandler(buf);
        NSError *wrtieFromBufferError = nil;
        [file writeFromBuffer:buf error:&wrtieFromBufferError];
    }];
}

- (void)start {
    if (engine == nil) {
        if (_completionHandler != nil && fileUrl != nil) {
            [self prepare:fileUrl handler:_completionHandler];
        } else {
            NSLog(@"Have to prepare before start");
            return;
        }
    }
    
    NSError *error = nil;
    if (![engine startAndReturnError:&error]) {
        NSLog(@"engine failed to start: %@", error);
        return;
    }
}

- (void)pause {
    [engine pause];
}

- (void)stop {
    AVAudioInputNode *input = [engine inputNode];
    [input removeTapOnBus: 0];
    [engine stop];
    engine = nil;
}

@end
