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
    AVAudioEngine *_engine;
    void (^_audioDataReceived)(AVAudioPCMBuffer *buf);
    NSURL *_fileUrl;
    NSDictionary *_settings;
    AVAudioMixerNode *_downMixer;
    NSTimeInterval _startTime;
    
    @public
    bool recording;
    NSTimeInterval currentTime;
}

- (void)prepare:(NSURL*)recordingFileUrl settings:(NSDictionary*)settings handler:(void(^)(AVAudioPCMBuffer *))handler;
- (void)start;
- (void)pause;
- (void)stop;

@end
