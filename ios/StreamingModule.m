//
//  StreamingModule.c
//  RNAudio
//
//  Created by JeungminOh on 30/05/2017.
//  Copyright © 2017 Joshua Sierles. All rights reserved.
//

#import "StreamingModule.h"

@implementation StreamingModule

- (void)prepare:(NSURL *)recordingFileUrl settings:(NSDictionary*)settings handler:(void(^)(AVAudioPCMBuffer *))handler {
    _audioDataReceived = [handler copy];
    _fileUrl = recordingFileUrl;
    _settings = settings;
    
    _engine = [[AVAudioEngine alloc] init];
    
    /*
    // Initialize audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *setCateegoryError = nil;
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&setCateegoryError];
    */
    
    AVAudioInputNode *input = [_engine inputNode];
    _downMixer = [[AVAudioMixerNode alloc] init];
    AVAudioMixerNode *mainMixer = [_engine mainMixerNode];
    
    NSLog(@"Prepare");
    NSLog(@"%@", [settings description]);
    
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate: [_settings[AVSampleRateKey] doubleValue]
                                                                           channels: [_settings[AVNumberOfChannelsKey] intValue]];
    
    NSLog(@"%@", [format description]);
    
    [_engine attachNode:_downMixer];
    [_engine connect:input to:_downMixer format:[input inputFormatForBus:0]];
    [_downMixer setVolume:0];
    [_engine connect:_downMixer to:mainMixer format:format];

    NSError *error = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForWriting:_fileUrl
                                                   settings:format.settings
                                                      error:&error];
    
    NSLog(@"InstallTapOnBus");
    
    [_downMixer installTapOnBus: 0 bufferSize: 8192 format: format block: ^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
        // ‘buf' contains audio captured from input node at time 'when'
        _audioDataReceived(buf);
        NSError *wrtieFromBufferError = nil;
        [file writeFromBuffer:buf error:&wrtieFromBufferError];
    }];
    
    [_engine prepare];
}

- (void)start {
    if (_engine == nil) {
        if (_audioDataReceived != nil && _fileUrl != nil && _settings != nil) {
            [self prepare:_fileUrl settings:_settings handler:_audioDataReceived];
        } else {
            NSLog(@"Have to prepare before start");
            return;
        }
    }
    
    NSError *error = nil;
    if (![_engine startAndReturnError:&error]) {
        NSLog(@"engine failed to start: %@", error);
        return;
    }
}

- (void)pause {
    [_engine pause];
}

- (void)stop {
    [_downMixer removeTapOnBus: 0];
    [_engine stop];
    _engine = nil;
}

@end
