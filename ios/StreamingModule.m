//
//  StreamingModule.c
//  RNAudio
//
//  Created by JeungminOh on 30/05/2017.
//  Copyright © 2017 Joshua Sierles. All rights reserved.
//

#import "StreamingModule.h"
#import <Foundation/NSObjCRuntime.h>

// Declare C callback functions
void AudioInputCallback(void * inUserData,  // Custom audio metadata
                        AudioQueueRef inAQ,
                        AudioQueueBufferRef inBuffer,
                        const AudioTimeStamp * inStartTime,
                        UInt32 inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * inPacketDescs);

void AudioOutputCallback(void * inUserData,
                         AudioQueueRef outAQ,
                         AudioQueueBufferRef outBuffer);



@implementation StreamingModule

- init {
    if (self = [super init]) {
        // Your initialization code here
    }
    return self;
}

static const int kNumberBuffers = 3;                            // 1
struct AQRecorderState {
    AudioStreamBasicDescription  mDataFormat;                   // 2
    AudioQueueRef                mQueue;                        // 3
    AudioQueueBufferRef          mBuffers[kNumberBuffers];      // 4
    AudioFileID                  mAudioFile;                    // 5
    UInt32                       bufferByteSize;                // 6
    SInt64                       mCurrentPacket;                // 7
    bool                         mIsRunning;                    // 8
};

static void HandleInputBuffer (
                               void                                 *aqData,
                               AudioQueueRef                        inAQ,
                               AudioQueueBufferRef                  inBuffer,
                               const AudioTimeStamp                 *inStartTime,
                               UInt32                               inNumPackets,
                               const AudioStreamPacketDescription   *inPacketDesc
                               ) {
    AQRecorderState *pAqData = (AQRecorderState *) aqData;               // 1
    
    if (inNumPackets == 0 &&                                             // 2
        pAqData->mDataFormat.mBytesPerPacket != 0)
        inNumPackets =
        inBuffer->mAudioDataByteSize / pAqData->mDataFormat.mBytesPerPacket;
    
    if (AudioFileWritePackets (                                          // 3
                               pAqData->mAudioFile,
                               false,
                               inBuffer->mAudioDataByteSize,
                               inPacketDesc,
                               pAqData->mCurrentPacket,
                               &inNumPackets,
                               inBuffer->mAudioData
                               ) == noErr) {
        pAqData->mCurrentPacket += inNumPackets;                     // 4
    }
    if (pAqData->mIsRunning == 0)                                         // 5
        return;
    
    AudioQueueEnqueueBuffer (                                            // 6
                             pAqData->mQueue,
                             inBuffer,
                             0,
                             NULL
                             );
}

void DeriveBufferSize (
                       AudioQueueRef audioQueue,                  // 1
                       AudioStreamBasicDescription &ASBDescription,             // 2
                       Float64 seconds,                     // 3
                       UInt32 *outBufferSize               // 4
) {
    static const int maxBufferSize = 0x50000;                 // 5
    
    int maxPacketSize = ASBDescription.mBytesPerPacket;       // 6
    if (maxPacketSize == 0) {                                 // 7
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty (
                               audioQueue,
                               kAudioQueueProperty_MaximumOutputPacketSize,
                               // in Mac OS X v10.5, instead use
                               //   kAudioConverterPropertyMaximumOutputPacketSize
                               &maxPacketSize,
                               &maxVBRPacketSize
                               );
    }
    
    Float64 numBytesForTime =
    ASBDescription.mSampleRate * maxPacketSize * seconds; // 8
    *outBufferSize =
    UInt32 (numBytesForTime < maxBufferSize ?
            numBytesForTime : maxBufferSize);                     // 9
}


AQRecorderState aqData;
- (void)startRecording:(CFURLRef*)fileURL
{
    // AQRecorderState aqData;                                       // 1
    
    aqData.mDataFormat.mFormatID         = kAudioFormatLinearPCM; // 2
    aqData.mDataFormat.mSampleRate       = 44100.0;               // 3
    aqData.mDataFormat.mChannelsPerFrame = 2;                     // 4
    aqData.mDataFormat.mBitsPerChannel   = 16;                    // 5
    aqData.mDataFormat.mBytesPerPacket   =                        // 6
    aqData.mDataFormat.mBytesPerFrame =
    aqData.mDataFormat.mChannelsPerFrame * sizeof (SInt16);
    aqData.mDataFormat.mFramesPerPacket  = 1;                     // 7
    
    AudioFileTypeID fileType             = kAudioFileAIFFType;    // 8
    aqData.mDataFormat.mFormatFlags =                             // 9
    kLinearPCMFormatFlagIsBigEndian
    | kLinearPCMFormatFlagIsSignedInteger
    | kLinearPCMFormatFlagIsPacked;
    
    AudioQueueNewInput (                              // 1
                        &aqData.mDataFormat,                          // 2
                        HandleInputBuffer,                            // 3
                        &aqData,                                      // 4
                        NULL,                                         // 5
                        kCFRunLoopCommonModes,                        // 6
                        0,                                            // 7
                        &aqData.mQueue                                // 8
                        );
    
    UInt32 dataFormatSize = sizeof (aqData.mDataFormat);       // 1
    
    AudioQueueGetProperty (                                    // 2
                           aqData.mQueue,                                         // 3
                           kAudioQueueProperty_StreamDescription,                 // 4
                           // in Mac OS X, instead use
                           //    kAudioConverterCurrentInputStreamDescription
                           &aqData.mDataFormat,                                   // 5
                           &dataFormatSize                                        // 6
                           );
    
    DeriveBufferSize (                               // 1
                      aqData.mQueue,                               // 2
                      aqData.mDataFormat,                          // 3
                      0.5,                                         // 4
                      &aqData.bufferByteSize                       // 5
                      );
    
    for (int i = 0; i < kNumberBuffers; ++i) {           // 1
        AudioQueueAllocateBuffer (                       // 2
                                  aqData.mQueue,                               // 3
                                  aqData.bufferByteSize,                       // 4
                                  &aqData.mBuffers[i]                          // 5
                                  );
        
        AudioQueueEnqueueBuffer (                        // 6
                                 aqData.mQueue,                               // 7
                                 aqData.mBuffers[i],                          // 8
                                 0,                                           // 9
                                 NULL                                         // 10
                                 );
    }
    
    aqData.mCurrentPacket = 0;
    aqData.mIsRunning = true;
    AudioQueueStart(aqData.mQueue, NULL);

}

- (void)stopRecording
{
    // Wait, on user interface thread, until user stops the recording
    AudioQueueStop (aqData.mQueue, true);
    aqData.mIsRunning = false;
}

- (void)dealloc
{
    CFRelease(fileURL);
}

@end
