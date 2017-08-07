package com.rnim.rn.audio;

import android.Manifest;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.os.AsyncTask;
import android.os.Environment;
import android.media.MediaRecorder;
import android.support.v4.content.ContextCompat;
import android.util.Log;

import com.facebook.react.modules.core.DeviceEventManagerModule;

class AudioRecorderManager extends ReactContextBaseJavaModule {

  private static final String TAG = "ReactNativeAudio";

  private static final String DocumentDirectoryPath = "DocumentDirectoryPath";
  private static final String PicturesDirectoryPath = "PicturesDirectoryPath";
  private static final String MainBundlePath = "MainBundlePath";
  private static final String CachesDirectoryPath = "CachesDirectoryPath";
  private static final String LibraryDirectoryPath = "LibraryDirectoryPath";
  private static final String MusicDirectoryPath = "MusicDirectoryPath";
  private static final String DownloadsDirectoryPath = "DownloadsDirectoryPath";

  private String currentOutputFile;
  private boolean isRecording = false;
  private Timer timer;
  private int recorderSecondsElapsed;

  // For AudioRecord Class
  private RecordWaveTask recordTask = null;

  public AudioRecorderManager(ReactApplicationContext reactContext) {
    super(reactContext);
    if (recordTask == null) {
      recordTask = new RecordWaveTask();
    }
  }

  @Override
  public Map<String, Object> getConstants() {
    Map<String, Object> constants = new HashMap<>();
    constants.put(DocumentDirectoryPath, this.getReactApplicationContext().getFilesDir().getAbsolutePath());
    constants.put(PicturesDirectoryPath, Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES).getAbsolutePath());
    constants.put(MainBundlePath, "");
    constants.put(CachesDirectoryPath, this.getReactApplicationContext().getCacheDir().getAbsolutePath());
    constants.put(LibraryDirectoryPath, "");
    constants.put(MusicDirectoryPath, Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC).getAbsolutePath());
    constants.put(DownloadsDirectoryPath, Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).getAbsolutePath());
    return constants;
  }

  @Override
  public String getName() {
    return "AudioRecorderManager";
  }

  @ReactMethod
  public void checkAuthorizationStatus(Promise promise) {
    int permissionCheck = ContextCompat.checkSelfPermission(getCurrentActivity(),
            Manifest.permission.RECORD_AUDIO);
    boolean permissionGranted = permissionCheck == PackageManager.PERMISSION_GRANTED;
    promise.resolve(permissionGranted);
  }

  private int getAudioEncoderFromString(String audioEncoder) {
    switch (audioEncoder) {
      case "aac":
        return MediaRecorder.AudioEncoder.AAC;
      case "aac_eld":
        return MediaRecorder.AudioEncoder.AAC_ELD;
      case "amr_nb":
        return MediaRecorder.AudioEncoder.AMR_NB;
      case "amr_wb":
        return MediaRecorder.AudioEncoder.AMR_WB;
      case "he_aac":
        return MediaRecorder.AudioEncoder.HE_AAC;
      case "vorbis":
        return MediaRecorder.AudioEncoder.VORBIS;
      default:
        Log.d("INVALID_AUDIO_ENCODER", "USING MediaRecorder.AudioEncoder.DEFAULT instead of "+audioEncoder+": "+MediaRecorder.AudioEncoder.DEFAULT);
        return MediaRecorder.AudioEncoder.DEFAULT;
    }
  }

  private int getOutputFormatFromString(String outputFormat) {
    switch (outputFormat) {
      case "mpeg_4":
        return MediaRecorder.OutputFormat.MPEG_4;
      case "aac_adts":
        return MediaRecorder.OutputFormat.AAC_ADTS;
      case "amr_nb":
        return MediaRecorder.OutputFormat.AMR_NB;
      case "amr_wb":
        return MediaRecorder.OutputFormat.AMR_WB;
      case "three_gpp":
        return MediaRecorder.OutputFormat.THREE_GPP;
      case "webm":
        return MediaRecorder.OutputFormat.WEBM;
      default:
        Log.d("INVALID_OUPUT_FORMAT", "USING MediaRecorder.OutputFormat.DEFAULT : "+MediaRecorder.OutputFormat.DEFAULT);
        return MediaRecorder.OutputFormat.DEFAULT;

    }
  }

  @ReactMethod
  public void prepareStreamingAtPath(String recordingPath, int bufferSize, ReadableMap recordingSettings, Promise promise) {

    try {
      File wavFile = new File(recordingPath);
      recordTask = new RecordWaveTask();

      recordTask.setAudioSource(MediaRecorder.AudioSource.MIC);

      if (recordingSettings.hasKey("SampleRate")) {
        recordTask.setSampleRate(recordingSettings.getInt("SampleRate"));
      }

      if (recordingSettings.hasKey("Channels")) {
        int channels = recordingSettings.getInt("Channels");
        int channelMask = AudioFormat.CHANNEL_IN_STEREO;
        if (channels == 1) {
          channelMask = AudioFormat.CHANNEL_IN_MONO;
        }
        recordTask.setChannelMask(channelMask);
      }

      recordTask.setBufferSize(bufferSize);

      recordTask.setOutputFile(wavFile);
      recordTask.setStreamListener(new RecordWaveTask.OnStreamListener() {

        @Override
        public void onDataReceived(short[] buffer) {
          Log.d("onDataReceived", buffer.length + "");
          WritableArray body = Arguments.createArray();
          for (short value: buffer) {
            body.pushInt((int) value);
          }
          sendEvent("dataReceived", body);
        }
      });

      recordTask.setVadListener(new RecordWaveTask.OnVadListener() {

        @Override
        public void onVadReceived(int vadResult) {
          Log.d("onVadReceived", vadResult + "");
          // WritableMap body = Arguments.createMap();
          // body.putInt("vadResult", vadResult);
          sendEvent("vadReceived", vadResult);
        }
      });

      // int outputFormat = getOutputFormatFromString(recordingSettings.getString("OutputFormat"));
      // recorder.setOutputFormat(outputFormat);
      // int audioEncoder = getAudioEncoderFromString(recordingSettings.getString("AudioEncoding"));
      // recorder.setAudioEncoder(audioEncoder);
      // recorder.setAudioEncodingBitRate(recordingSettings.getInt("AudioEncodingBitRate"));
    }
    catch(final Exception e) {
      logAndRejectPromise(promise, "COULDNT_CONFIGURE_MEDIA_RECORDER" , "Make sure you've added RECORD_AUDIO permission to your AndroidManifest.xml file "+e.getMessage());
      return;
    }

    currentOutputFile = recordingPath;
  }

  @ReactMethod
  public void startStreaming(Promise promise){
    if (recordTask == null){
      logAndRejectPromise(promise, "STREAMING_NOT_PREPARED", "Please call prepareStreamingAtPath before starting streaming");
      return;
    }
    switch (recordTask.getStatus()) {
      case RUNNING:
        logAndRejectPromise(promise, "INVALID_STATE", "Please call stopStreaming before starting streaming");
        return;
      case FINISHED:
        logAndRejectPromise(promise, "STREAMING_NOT_PREPARED", "Please call prepareStreamingAtPath before starting streaming");
        break;
      case PENDING:
        // No Action
    }
    startTimer();

    recordTask.execute();

    isRecording = true;
    promise.resolve(currentOutputFile);
  }

  @ReactMethod
  public void stopStreaming(final Promise promise){
    Log.d("RecordWaveTask", "stopStreaming");
    if (!recordTask.isCancelled() && recordTask.getStatus() == AsyncTask.Status.RUNNING) {
      Log.d("RecordWaveTask", "stopStreaming2");
      isRecording = false;
      recordTask.setCancelCompleteListener(new RecordWaveTask.OnCancelCompleteListener() {
        @Override
        public void onCancelCompleted() {
          Log.d("RecordWaveTask", "onCancelCompleted");
          recordTask = null;
          promise.resolve(currentOutputFile);
          sendEvent("recordingFinished", null);
        }
      });
      recordTask.cancel(false);
      stopTimer();
    } else {
      Log.d("RecordWaveTask", "Task not running.");
      logAndRejectPromise(promise, "INVALID_STATE", "Please call startStreaming before stopping streaming");
    }
  }

  @ReactMethod
  public void pauseStreaming(Promise promise){
    // Added this function to have the same api for android and iOS, stops recording now
    stopStreaming(promise);
  }

  private void startTimer(){
    stopTimer();
    timer = new Timer();
    timer.scheduleAtFixedRate(new TimerTask() {
      @Override
      public void run() {
        WritableMap body = Arguments.createMap();
        body.putInt("currentTime", recorderSecondsElapsed);
        sendEvent("recordingProgress", body);
        recorderSecondsElapsed++;
      }
    }, 0, 1000);
  }

  private void stopTimer(){
    recorderSecondsElapsed = 0;
    if (timer != null) {
      timer.cancel();
      timer.purge();
      timer = null;
    }
  }

  private void sendEvent(String eventName, Object params) {
    getReactApplicationContext()
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit(eventName, params);
  }

  private void logAndRejectPromise(Promise promise, String errorCode, String errorMessage) {
    Log.e(TAG, errorMessage);
    promise.reject(errorCode, errorMessage);
  }

}
