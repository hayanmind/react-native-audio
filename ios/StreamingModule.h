//
//  StreamingModule.h
//  RNAudio
//
//  Created by JeungminOh on 30/05/2017.
//  Copyright © 2017 Joshua Sierles. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface StreamingModule : NSObject
{
    AVAudioEngine *engine;
    void (^_completionHandler)(AVAudioPCMBuffer *buf);
    NSTimeInterval currentTime;
    NSURL *fileUrl;
}

- (void)prepare:(NSURL*)recordingFileUrl handler:(void(^)(AVAudioPCMBuffer *))handler;
- (void)start;
- (void)pause;
- (void)stop;

@end
