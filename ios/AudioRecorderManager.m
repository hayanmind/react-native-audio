//
//  AudioRecorderManager.m
//  AudioRecorderManager
//
//  Created by Joshua Sierles on 15/04/15.
//  Copyright (c) 2015 Joshua Sierles. All rights reserved.
//

#import "AudioRecorderManager.h"
#import <React/RCTConvert.h>
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
#import <React/RCTEventDispatcher.h>
#import <AVFoundation/AVFoundation.h>
#import "StreamingModule.h"

NSString *const AudioRecorderEventProgress = @"recordingProgress";
NSString *const AudioRecorderEventFinished = @"recordingFinished";
NSString *const AudioRecorderEventDataReceived = @"dataReceived";

@implementation AudioRecorderManager {

  // AVAudioRecorder *_audioRecorder;

  NSTimeInterval _currentTime;
  id _progressUpdateTimer;
  int _progressUpdateInterval;
  NSDate *_prevProgressUpdateTime;
  NSURL *_audioFileURL;
  NSNumber *_audioQuality;
  NSNumber *_audioEncoding;
  NSNumber *_audioChannels;
  NSNumber *_audioSampleRate;
  BOOL _meteringEnabled;
  int _bufferSize;
}

StreamingModule* streamingModule;

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (void)sendProgressUpdate {
  if (streamingModule && streamingModule->recording) {
    _currentTime = streamingModule->currentTime;
  } else {
    return;
  }

  if (_prevProgressUpdateTime == nil ||
   (([_prevProgressUpdateTime timeIntervalSinceNow] * -1000.0) >= _progressUpdateInterval)) {
      NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
      [body setObject:[NSNumber numberWithFloat:_currentTime] forKey:@"currentTime"];
      /*
      if (_meteringEnabled) {
          [_audioRecorder updateMeters];
          float _currentMetering = [_audioRecorder averagePowerForChannel: 0];
          [body setObject:[NSNumber numberWithFloat:_currentMetering] forKey:@"currentMetering"];
      }
       */

      [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventProgress body:body];

    _prevProgressUpdateTime = [NSDate date];
  }
}

- (void)stopProgressTimer {
  [_progressUpdateTimer invalidate];
}

- (void)startProgressTimer {
  _progressUpdateInterval = 250;
  _prevProgressUpdateTime = nil;

  [self stopProgressTimer];

  _progressUpdateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(sendProgressUpdate)];
  [_progressUpdateTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)finishRecording:(BOOL)flag {
    [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventFinished body:@{
        @"status": flag ? @"OK" : @"ERROR",
        @"audioFileURL": [_audioFileURL absoluteString]
    }];
}

- (NSString *) applicationDocumentsDirectory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
  return basePath;
}

RCT_EXPORT_METHOD(checkAuthorizationStatus:(RCTPromiseResolveBlock)resolve reject:(__unused RCTPromiseRejectBlock)reject)
{
  AVAudioSessionRecordPermission permissionStatus = [[AVAudioSession sharedInstance] recordPermission];
  switch (permissionStatus) {
    case AVAudioSessionRecordPermissionUndetermined:
      resolve(@("undetermined"));
    break;
    case AVAudioSessionRecordPermissionDenied:
      resolve(@("denied"));
      break;
    case AVAudioSessionRecordPermissionGranted:
      resolve(@("granted"));
      break;
    default:
      reject(RCTErrorUnspecified, nil, RCTErrorWithMessage(@("Error checking device authorization status.")));
      break;
  }
}

RCT_EXPORT_METHOD(requestAuthorization:(RCTPromiseResolveBlock)resolve
                  rejecter:(__unused RCTPromiseRejectBlock)reject)
{
  [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
    if(granted) {
      resolve(@YES);
    } else {
      resolve(@NO);
    }
  }];
}

RCT_EXPORT_METHOD(prepareStreamingAtPath:(NSString *)path bufferSize:(int)bufferSize sampleRate:(float)sampleRate channels:(nonnull NSNumber *)channels quality:(NSString *)quality encoding:(NSString *)encoding meteringEnabled:(BOOL)meteringEnabled)
{
    NSLog(@"prepareStreaming");
    _audioFileURL = [NSURL fileURLWithPath:path];
    
    // Default options
    _audioQuality = [NSNumber numberWithInt:AVAudioQualityHigh];
    _audioEncoding = [NSNumber numberWithInt:kAudioFormatAppleIMA4];
    _audioChannels = [NSNumber numberWithInt:1];
    _audioSampleRate = [NSNumber numberWithFloat:44100.0];
    _meteringEnabled = NO;
    _bufferSize = 8192;
    
    // Set audio quality from options
    if (quality != nil) {
        if ([quality  isEqual: @"Low"]) {
            _audioQuality =[NSNumber numberWithInt:AVAudioQualityLow];
        } else if ([quality  isEqual: @"Medium"]) {
            _audioQuality =[NSNumber numberWithInt:AVAudioQualityMedium];
        } else if ([quality  isEqual: @"High"]) {
            _audioQuality =[NSNumber numberWithInt:AVAudioQualityHigh];
        }
    }
    
    // Set channels from options
    if (channels != nil) {
        _audioChannels = channels;
    }
    
    // Set audio encoding from options
    if (encoding != nil) {
        if ([encoding  isEqual: @"lpcm"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatLinearPCM];
        } else if ([encoding  isEqual: @"ima4"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatAppleIMA4];
        } else if ([encoding  isEqual: @"aac"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatMPEG4AAC];
        } else if ([encoding  isEqual: @"MAC3"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatMACE3];
        } else if ([encoding  isEqual: @"MAC6"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatMACE6];
        } else if ([encoding  isEqual: @"ulaw"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatULaw];
        } else if ([encoding  isEqual: @"alaw"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatALaw];
        } else if ([encoding  isEqual: @"mp1"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatMPEGLayer1];
        } else if ([encoding  isEqual: @"mp2"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatMPEGLayer2];
        } else if ([encoding  isEqual: @"alac"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatAppleLossless];
        } else if ([encoding  isEqual: @"amr"]) {
            _audioEncoding =[NSNumber numberWithInt:kAudioFormatAMR];
        }
    }
    
    // Set sample rate from options
    _audioSampleRate = [NSNumber numberWithFloat:sampleRate];
    
    // Set buffer size from options
    _bufferSize = bufferSize;
    
    NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    //_audioQuality, AVEncoderAudioQualityKey,
                                    //_audioEncoding, AVFormatIDKey,
                                    _audioChannels, AVNumberOfChannelsKey,
                                    _audioSampleRate, AVSampleRateKey,
                                    nil];
    
    // Enable metering from options
    if (meteringEnabled != NO) {
        _meteringEnabled = meteringEnabled;
    }
    
    streamingModule = [[StreamingModule alloc] init];
    [streamingModule prepare:_audioFileURL
                  bufferSize:_bufferSize
                    settings:recordSettings
                     handler:^(AVAudioPCMBuffer *buf){
                         NSMutableArray *body = [[NSMutableArray alloc] init];
                         for(int i=0; i<buf.frameLength; i++) {
                             for (int channel=0; channel<buf.format.channelCount; channel++) {
                                 int16_t * const channelData = [buf int16ChannelData][channel];
                                 NSNumber *value = [NSNumber numberWithInt:channelData[i]];
                                 [body addObject: value];
                             }
                         }
                         [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventDataReceived body:body];
                     }
     ];
}

RCT_EXPORT_METHOD(startStreaming)
{
    NSLog(@"startStreaming");
    NSLog(@"%@", _audioFileURL);
    [self startProgressTimer];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [streamingModule start];
}

RCT_EXPORT_METHOD(stopStreaming)
{
    NSLog(@"stopStreaming");
    [streamingModule stop];
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
    _prevProgressUpdateTime = nil;
    [self finishRecording: true];
}

RCT_EXPORT_METHOD(pauseStreaming)
{
    NSLog(@"pauseStreaming");
    [self stopProgressTimer];
    [streamingModule pause];
}


- (NSString *)getPathForDirectory:(int)directory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
  return [paths firstObject];
}

- (NSDictionary *)constantsToExport
{
  return @{
    @"MainBundlePath": [[NSBundle mainBundle] bundlePath],
    @"NSCachesDirectoryPath": [self getPathForDirectory:NSCachesDirectory],
    @"NSDocumentDirectoryPath": [self getPathForDirectory:NSDocumentDirectory],
    @"NSLibraryDirectoryPath": [self getPathForDirectory:NSLibraryDirectory]
  };
}

@end
