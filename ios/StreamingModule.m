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
    _downMixer = [[AVAudioMixerNode alloc] init];
    AVAudioMixerNode *mainMixer = [_engine mainMixerNode];
    
    NSLog(@"Prepare");
    NSLog(@"%@", [settings description]);
    
    
    AVAudioFormat *format =
        [[AVAudioFormat alloc] initWithCommonFormat: AVAudioPCMFormatFloat32
                                         sampleRate: [_settings[AVSampleRateKey] doubleValue]
                                           channels: [_settings[AVNumberOfChannelsKey] intValue]
                                        interleaved: NO
        ];
    
    AVAudioFormat *pcmInt16Format =
        [[AVAudioFormat alloc] initWithCommonFormat: AVAudioPCMFormatInt16
                                     sampleRate: [_settings[AVSampleRateKey] doubleValue]
                                       channels: [_settings[AVNumberOfChannelsKey] intValue]
                                    interleaved: NO
        ];

    
    /*
    AVAudioFormat *format =
        [[AVAudioFormat alloc] initStandardFormatWithSampleRate: [_settings[AVSampleRateKey] doubleValue]
                                                       channels: [_settings[AVNumberOfChannelsKey] intValue]];
    */
    
    NSLog(@"%@", [format description]);
    
    [_engine attachNode:_downMixer];
    [_engine connect:input to:_downMixer format:[input inputFormatForBus:0]];
    [_downMixer setVolume:0];
    [_engine connect:_downMixer to:mainMixer format:format];

    NSError *error = nil;
    /*
    AVAudioFile *file = [[AVAudioFile alloc] initForWriting:_fileUrl
                                                   settings:pcmInt16Format.settings
                                                      error:&error];
    */
    AVAudioFile *file = [[AVAudioFile alloc] initForWriting:_fileUrl
                                                   settings:pcmInt16Format.settings
                                               commonFormat:AVAudioPCMFormatInt16
                                                interleaved:NO
                                                      error:&error];
    
    NSLog(@"InstallTapOnBus");
    
    [_downMixer installTapOnBus: 0 bufferSize: 8192 format: format block: ^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
        // ‘buf' contains audio captured from input node at time 'when'
        currentTime = when.sampleTime / when.sampleRate - _startTime;
        
        // convert AVAudioPCMFormatFloat32 to AVAudioPCMFormatInt16
        AVAudioPCMBuffer *pcmInt16Buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:pcmInt16Format
                                                                        frameCapacity:[buf frameCapacity]];
        
        [pcmInt16Buffer setFrameLength: [buf frameLength]];
        
        int16_t * const int16Left = [pcmInt16Buffer int16ChannelData][0];
        float * const float32Left = [buf floatChannelData][0];
        
        for(int i=0; i<buf.frameLength; i++) {
            float floatValue = float32Left[i];
            int16_t int16Value = (int16_t) (floatValue * 32768.0);
            // NSLog(@"%f-%hd", (floatValue * 32768.0), int16Value);
            int16Left[i] = int16Value;
        }
        
        NSLog(@"audioBufferList1: %d", [buf audioBufferList]->mNumberBuffers);
        NSLog(@"audioBufferList2: %d", [pcmInt16Buffer audioBufferList]->mNumberBuffers);
        
        NSLog(@"audioBufferList1: %d", [buf audioBufferList]->mBuffers->mDataByteSize);
        NSLog(@"audioBufferList2: %d", [pcmInt16Buffer audioBufferList]->mBuffers->mDataByteSize);
        
        // _audioDataReceived(pcmInt16Buffer);
        NSError *wrtieFromBufferError = nil;
        [file writeFromBuffer:pcmInt16Buffer error:&wrtieFromBufferError];
        if (wrtieFromBufferError != nil) {
            NSLog(@"%@", wrtieFromBufferError);
        }
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
    } else {
        _startTime = _downMixer.lastRenderTime.sampleTime / _downMixer.lastRenderTime.sampleRate;
        recording = true;
    }
}

- (void)pause {
    [_engine pause];
    recording = false;
}

- (void)stop {
    [_downMixer removeTapOnBus: 0];
    [_engine stop];
    _engine = nil;
    recording = false;
}

@end
