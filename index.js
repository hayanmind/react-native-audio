'use strict';

import React from "react";

import ReactNative, {
  NativeModules,
  NativeAppEventEmitter,
  DeviceEventEmitter,
  Platform
} from "react-native";

var AudioRecorderManager = NativeModules.AudioRecorderManager;

var AudioRecorder = {
  prepareStreamingAtPath: function(path, bufferSize=8192, options, vadOptions) {
    if (this.progressSubscription) this.progressSubscription.remove();
    this.progressSubscription = NativeAppEventEmitter.addListener('recordingProgress',
      (data) => {
        if (this.onProgress) {
          this.onProgress(data);
        }
      }
    );

    if (this.finishedSubscription) this.finishedSubscription.remove();
    this.finishedSubscription = NativeAppEventEmitter.addListener('recordingFinished',
      (data) => {
        if (this.onFinished) {
          this.onFinished(data);
        }
      }
    );

    if (this.dataReceivedSubscription) this.dataReceivedSubscription.remove();
    this.dataReceivedSubscription = NativeAppEventEmitter.addListener('dataReceived',
      (data) => {
        if (this.onDataReceived) {
          this.onDataReceived(data);
        }
      }
    );

    if (this.vadReceivedSubscription) this.vadReceivedSubscription.remove();
    this.vadReceivedSubscription = NativeAppEventEmitter.addListener('vadReceived',
      (vadResult) => {
        if (this.onVadReceived) {
          this.onVadReceived(vadResult);
        }
      }
    );

    var defaultOptions = {
      SampleRate: 44100.0,
      Channels: 1,
      AudioQuality: 'High',
      AudioEncoding: 'ima4',
      MeteringEnabled: false,
      AudioSource: 'DEFAULT',
      // OutputFormat: 'mpeg_4',
      // AudioEncodingBitRate: 32000
    };

    var recordingOptions = {...defaultOptions, ...options};

    var defaultVadOptions = {
      Sensitivity: 0,
      Timeout: 7000,
    }

    var vadOptions = {...defaultVadOptions, ...vadOptions};

    if (Platform.OS === 'ios') {
      AudioRecorderManager.prepareStreamingAtPath(
        path,
        bufferSize,
        recordingOptions.SampleRate,
        recordingOptions.Channels,
        recordingOptions.AudioQuality,
        recordingOptions.AudioEncoding,
        recordingOptions.MeteringEnabled,
        vadOptions.Sensitivity,
        vadOptions.Timeout,
      );
    } else {
      return AudioRecorderManager.prepareStreamingAtPath(path, bufferSize, recordingOptions, vadOptions);
    }
  },
  startStreaming: function() {
    return AudioRecorderManager.startStreaming();
  },
  stopStreaming: function() {
    return AudioRecorderManager.stopStreaming();
  },
  pauseStreaming: function() {
    return AudioRecorderManager.pauseStreaming();
  },
  checkAuthorizationStatus: AudioRecorderManager.checkAuthorizationStatus,
  requestAuthorization: AudioRecorderManager.requestAuthorization,
  removeListeners: function() {
    if (this.progressSubscription) this.progressSubscription.remove();
    if (this.finishedSubscription) this.finishedSubscription.remove();
    if (this.dataReceivedSubscription) this.dataReceivedSubscription.remove();
    if (this.vadReceivedSubscription) this.vadReceivedSubscription.remove();
  },
};

let AudioUtils = {};

if (Platform.OS === 'ios') {
  AudioUtils = {
    MainBundlePath: AudioRecorderManager.MainBundlePath,
    CachesDirectoryPath: AudioRecorderManager.NSCachesDirectoryPath,
    DocumentDirectoryPath: AudioRecorderManager.NSDocumentDirectoryPath,
    LibraryDirectoryPath: AudioRecorderManager.NSLibraryDirectoryPath,
  };
} else if (Platform.OS === 'android') {
  AudioUtils = {
    MainBundlePath: AudioRecorderManager.MainBundlePath,
    CachesDirectoryPath: AudioRecorderManager.CachesDirectoryPath,
    DocumentDirectoryPath: AudioRecorderManager.DocumentDirectoryPath,
    LibraryDirectoryPath: AudioRecorderManager.LibraryDirectoryPath,
    PicturesDirectoryPath: AudioRecorderManager.PicturesDirectoryPath,
    MusicDirectoryPath: AudioRecorderManager.MusicDirectoryPath,
    DownloadsDirectoryPath: AudioRecorderManager.DownloadsDirectoryPath
  };
}

module.exports = {AudioRecorder, AudioUtils};
