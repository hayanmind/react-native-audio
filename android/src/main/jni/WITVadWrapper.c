#include "WITCvad.h"
#include <jni.h>


static s_wv_detector_cvad_state* wit_vad_g_struct = 0;

int Java_com_rnim_rn_audio_RecordWaveTask_VadInit(JNIEnv *env, jobject obj, jint sample_rate, jint vadSensitivity, jint vadTimeout)
{
    vadSensitivity = (int)fmax(0,fmin(100,vadSensitivity)); //bounds-checking
    wit_vad_g_struct = wv_detector_cvad_init(sample_rate, (int)vadSensitivity, (int)vadTimeout);

    return 0;
}


int Java_com_rnim_rn_audio_RecordWaveTask_VadStillTalking(JNIEnv *env, jobject obj, jshortArray java_arr, jfloatArray java_fft_arr)
{
  short int *samples;
  float *fft_mags;
  int i, sum = 0;
  int result;
  jshort *native_arr = (*env)->GetShortArrayElements(env, java_arr, NULL);
  jfloat *native_fft_arr = (*env)->GetFloatArrayElements(env, java_fft_arr, NULL);
  int arr_len = wit_vad_g_struct->samples_per_frame;

  samples = malloc(sizeof(*samples) * arr_len);
  for (i = 0; i < arr_len; i++) {
    samples[i] = native_arr[i];
  }
  (*env)->ReleaseShortArrayElements(env, java_arr, native_arr, 0);

  fft_mags = malloc(sizeof(*fft_mags) * arr_len);
  for (i = 0; i < arr_len/2; i++) {
    fft_mags[i] = native_fft_arr[i];
  }
  (*env)->ReleaseFloatArrayElements(env, java_fft_arr, native_fft_arr, 0);

  result = wvs_cvad_detect_talking(wit_vad_g_struct, samples, fft_mags);
  free(samples);
  free(fft_mags);

  return result;
}

void Java_com_rnim_rn_audio_RecordWaveTask_VadClean()
{
    if (wit_vad_g_struct) {
        wv_detector_cvad_clean(wit_vad_g_struct);
        wit_vad_g_struct = 0;
    }
}

int Java_com_rnim_rn_audio_RecordWaveTask_GetVadSamplesPerFrame(){
    return wit_vad_g_struct->samples_per_frame;
}
