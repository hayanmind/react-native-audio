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
    
    AVAudioInputNode *input = [_engine inputNode];
    AVAudioMixerNode *mainMixer = [_engine mainMixerNode];
    // [mainMixer setOutputVolume: 0.0];
    AVAudioOutputNode *output = [_engine outputNode];
    
    NSLog(@"Prepare");
    NSLog(@"%@", [settings description]);
    
    //AVAudioFormat *format = [[AVAudioFormat alloc] initWithSettings:settings]; //[input outputFormatForBus: 0]; //
    
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:22050 channels:1];
    
    // AVAudioFormat *format = [mainMixer outputFormatForBus: 0];
    NSLog(@"%@", [format description]);
    
    
    [_engine connect:input to:mainMixer format:[input inputFormatForBus:0]];
    [_engine connect:mainMixer to:output format:format];
    
    NSError *error = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForWriting:_fileUrl
                                                   settings:format.settings
                                                      error:&error];
    
    NSLog(@"InstallTapOnBus");
    
    [mainMixer installTapOnBus: 0 bufferSize: 8192 format: format block: ^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
        // ‘buf' contains audio captured from input node at time 'when'
        _audioDataReceived(buf);
        NSError *wrtieFromBufferError = nil;
        [file writeFromBuffer:buf error:&wrtieFromBufferError];
    }];
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
    AVAudioMixerNode *mainMixer = [_engine mainMixerNode];
    [mainMixer removeTapOnBus: 0];
    [_engine stop];
    _engine = nil;
}

@end
