package com.rnim.rn.audio;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.AsyncTask;
import android.os.SystemClock;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

import java.util.Arrays;
import org.jtransforms.fft.FloatFFT_1D;

/**
 * Created by KDH on 2017. 5. 15..
 */

public class RecordWaveTask extends AsyncTask<File, Void, Object[]> {

    // Default value
    private int AUDIO_SOURCE = MediaRecorder.AudioSource.DEFAULT;
    private int SAMPLE_RATE = 44100; // Hz
    private int ENCODING = AudioFormat.ENCODING_PCM_16BIT;
    private int CHANNEL_MASK = AudioFormat.CHANNEL_IN_MONO;
    private int BUFFER_SIZE_IN_FRAME = 8192;
    private int vadSensitivity = 0;
    private int vadTimeout = 7000;
    // int BUFFER_SIZE = 2 * AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_MASK, ENCODING);

    private File outputFile;

    static {
        System.loadLibrary("witvad");
    }

    public native int VadInit(int sampleRate, int vadSensitivity, int vadTimeout);
    public native int VadStillTalking(short[] samples, float[] fft_mags);
    public native int GetVadSamplesPerFrame();
    public native void VadClean();

    public RecordWaveTask() {}
    public void setAudioSource(int audioSource) { this.AUDIO_SOURCE = audioSource; }

    public void setSampleRate(int sampleRate) { this.SAMPLE_RATE = sampleRate; }

    public void setEncoding(int encoding) { this.ENCODING = encoding; }

    public void setChannelMask(int channelMask) { this.CHANNEL_MASK = channelMask; }

    public void setOutputFile(File file) { this.outputFile = file; }

    public void setBufferSize(int bufferSizeInFrame) { this.BUFFER_SIZE_IN_FRAME = bufferSizeInFrame; }

    public void setVadSensitivity(int vadSensitivity) { this.vadSensitivity = vadSensitivity; }

    public void setVadTimeout(int vadTimeout) { this.vadTimeout = vadTimeout; }

    // Step 1 - This interface defines the type of messages I want to communicate to my owner
    public interface OnCancelCompleteListener {
        public void onCancelCompleted();
    }
    private OnCancelCompleteListener cancelCompleteListener = null;

    public void setCancelCompleteListener(OnCancelCompleteListener listener) {
        this.cancelCompleteListener = listener;
    }

    public interface OnStreamListener {
        public void onDataReceived(short[] buffer);
    }
    private OnStreamListener streamListener = null;

    public void setStreamListener(OnStreamListener listener) {
        this.streamListener = listener;
    }

    public interface OnVadListener {
        public void onVadReceived(int vadResult);
    }
    private OnVadListener vadListener = null;

    public void setVadListener(OnVadListener listener) {
        this.vadListener = listener;
    }

    /**
     * Opens up the given file, writes the header, and keeps filling it with raw PCM bytes from
     * AudioRecord until it reaches 4GB or is stopped by the user. It then goes back and updates
     * the WAV header to include the proper final chunk sizes.
     *
     * @return Either an Exception (error) or two longs, the filesize, elapsed time in ms (success)
     */
    @Override
    protected Object[] doInBackground(File... unused) {
        AudioRecord audioRecord = null;
        FileOutputStream wavOut = null;

        long startTime = 0;
        long endTime = 0;

        try {
            // Open our two resources
            int bufferSizeInBytes = BUFFER_SIZE_IN_FRAME * 2;
            audioRecord = new AudioRecord(AUDIO_SOURCE, SAMPLE_RATE, CHANNEL_MASK, ENCODING, bufferSizeInBytes);
            wavOut = new FileOutputStream(this.outputFile);

            // Write out the wav file header
            writeWavHeader(wavOut, CHANNEL_MASK, SAMPLE_RATE, ENCODING);

            // Avoiding loop allocations
            short[] buffer = new short[BUFFER_SIZE_IN_FRAME];
            boolean run = true;
            int read;
            long total = 0;
            int vadResult;

            VadInit(SAMPLE_RATE, vadSensitivity, vadTimeout);

            FloatFFT_1D fft = new FloatFFT_1D(GetVadSamplesPerFrame());
            float[] fft_mags = new float[GetVadSamplesPerFrame()/2];
            float[] fft_modules = new float[GetVadSamplesPerFrame()];
            short[] samples;

            // Let's go
            startTime = SystemClock.elapsedRealtime();
            audioRecord.startRecording();
            while (run && !isCancelled()) {
                read = audioRecord.read(buffer, 0, buffer.length); // Count for 16 bit PCM

                int samplesAnalyzed = 0;
                while(samplesAnalyzed + GetVadSamplesPerFrame() < read){
                    samples = Arrays.copyOfRange(buffer, samplesAnalyzed, samplesAnalyzed +GetVadSamplesPerFrame());
                    for(int i=0; i<GetVadSamplesPerFrame(); i++){
                        fft_modules[i] = (float)samples[i];
                    }
                    fft.realForward(fft_modules); //results are stored in place

                    //transform to magnitudes
                    fft_mags[0]=fft_modules[0];
                    //the 0th (DC) component is different and has no imaginary part
                    for(int i=1; i<GetVadSamplesPerFrame()/2; i++){
                        fft_mags[i]=(float)Math.sqrt(Math.pow(fft_modules[2*i],2)+Math.pow(fft_modules[2*i+1],2));
                    }

                    vadResult = VadStillTalking(buffer, fft_mags);

                    if (this.vadListener != null) {
                        if (vadResult != -1) {
                            this.vadListener.onVadReceived(vadResult);
                        }
                    }
                    
                    samplesAnalyzed+=GetVadSamplesPerFrame();
                }                

                // WAVs cannot be > 4 GB due to the use of 32 bit unsigned integers.
                if (total + read > 4294967295L) {
                    // Write as many bytes as we can before hitting the max size
                    short[] tmpBuffer = new short[BUFFER_SIZE_IN_FRAME];
                    for (int i = 0; i < read && total <= 4294967295L; i++, total+=2) {
                        ByteBuffer byteBuffer = ByteBuffer.allocate(2);
                        byteBuffer.putShort(buffer[i]);
                        wavOut.write(byteBuffer.array());
                        tmpBuffer[i] = buffer[i];
                    }
                    if (this.streamListener != null) {
                        this.streamListener.onDataReceived(tmpBuffer);
                    }
                    run = false;
                } else if (read >= 0) {
                    // Short array to byte array 
                    ByteBuffer byteBuffer = ByteBuffer.allocate(buffer.length * 2);
                    byteBuffer.order(ByteOrder.LITTLE_ENDIAN);
                    byteBuffer.asShortBuffer().put(buffer);
                    byte[] bytes = byteBuffer.array();

                    wavOut.write(bytes, 0, read * 2);

                    total += (read * 2); // 2 Byte = Short
                    if (this.streamListener != null) {
                        Log.d("onDataReceived", "RecordWaveTask - " + read + "");
                        this.streamListener.onDataReceived(buffer.clone());
                    }
                }
            }
        } catch (IOException ex) {
            return new Object[]{ex};
        } finally {
            Log.d("RecordWaveTask", "Finally");
            if (audioRecord != null) {
                try {
                    if (audioRecord.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) {
                        VadClean();
                        audioRecord.stop();
                        Log.d("RecordWaveTask", "audioRecord.stop()");
                        endTime = SystemClock.elapsedRealtime();
                    }
                } catch (IllegalStateException ex) {
                    //
                }
                if (audioRecord.getState() == AudioRecord.STATE_INITIALIZED) {
                    audioRecord.release();
                }
            }
            if (wavOut != null) {
                try {
                    wavOut.close();
                    Log.d("RecordWaveTask", "wavOut.close()");
                } catch (IOException ex) {
                    Log.d("RecordWaveTask", ex.getMessage());
                }
            }
        }

        try {
            // This is not put in the try/catch/finally above since it needs to run
            // after we close the FileOutputStream
            this.updateWavHeader(this.outputFile);
        } catch (IOException ex) {
            Log.d("RecordWaveTask", ex.getMessage());
            return new Object[] { ex };
        }

        Log.d("RecordWaveTask", (endTime - startTime) + " sec" );
        Log.d("RecordWaveTask", this.outputFile.length() + " byte" );

        return new Object[] { this.outputFile.length(), endTime - startTime };
    }

    /**
     * Writes the proper 44-byte RIFF/WAVE header to/for the given stream
     * Two size fields are left empty/null since we do not yet know the final stream size
     *
     * @param out         The stream to write the header to
     * @param channelMask An AudioFormat.CHANNEL_* mask
     * @param sampleRate  The sample rate in hertz
     * @param encoding    An AudioFormat.ENCODING_PCM_* value
     * @throws IOException
     */
    private static void writeWavHeader(OutputStream out, int channelMask, int sampleRate, int encoding) throws IOException {
        short channels;
        switch (channelMask) {
            case AudioFormat.CHANNEL_IN_MONO:
                channels = 1;
                break;
            case AudioFormat.CHANNEL_IN_STEREO:
                channels = 2;
                break;
            default:
                throw new IllegalArgumentException("Unacceptable channel mask");
        }

        short bitDepth;
        switch (encoding) {
            case AudioFormat.ENCODING_PCM_8BIT:
                bitDepth = 8;
                break;
            case AudioFormat.ENCODING_PCM_16BIT:
                bitDepth = 16;
                break;
            case AudioFormat.ENCODING_PCM_FLOAT:
                bitDepth = 32;
                break;
            default:
                throw new IllegalArgumentException("Unacceptable encoding");
        }

        writeWavHeader(out, channels, sampleRate, bitDepth);
    }

    /**
     * Writes the proper 44-byte RIFF/WAVE header to/for the given stream
     * Two size fields are left empty/null since we do not yet know the final stream size
     *
     * @param out        The stream to write the header to
     * @param channels   The number of channels
     * @param sampleRate The sample rate in hertz
     * @param bitDepth   The bit depth
     * @throws IOException
     */
    private static void writeWavHeader(OutputStream out, short channels, int sampleRate, short bitDepth) throws IOException {
        // Convert the multi-byte integers to raw bytes in little endian format as required by the spec
        byte[] littleBytes = ByteBuffer
                .allocate(14)
                .order(ByteOrder.LITTLE_ENDIAN)
                .putShort(channels)
                .putInt(sampleRate)
                .putInt(sampleRate * channels * (bitDepth / 8))
                .putShort((short) (channels * (bitDepth / 8)))
                .putShort(bitDepth)
                .array();

        // Not necessarily the best, but it's very easy to visualize this way
        out.write(new byte[]{
                // RIFF header
                'R', 'I', 'F', 'F', // ChunkID
                0, 0, 0, 0, // ChunkSize (must be updated later)
                'W', 'A', 'V', 'E', // Format
                // fmt subchunk
                'f', 'm', 't', ' ', // Subchunk1ID
                16, 0, 0, 0, // Subchunk1Size
                1, 0, // AudioFormat
                littleBytes[0], littleBytes[1], // NumChannels
                littleBytes[2], littleBytes[3], littleBytes[4], littleBytes[5], // SampleRate
                littleBytes[6], littleBytes[7], littleBytes[8], littleBytes[9], // ByteRate
                littleBytes[10], littleBytes[11], // BlockAlign
                littleBytes[12], littleBytes[13], // BitsPerSample
                // data subchunk
                'd', 'a', 't', 'a', // Subchunk2ID
                0, 0, 0, 0, // Subchunk2Size (must be updated later)
        });
    }

    /**
     * Updates the given wav file's header to include the final chunk sizes
     *
     * @param wav The wav file to update
     * @throws IOException
     */
    private static void updateWavHeader(File wav) throws IOException {
        byte[] sizes = ByteBuffer
                .allocate(8)
                .order(ByteOrder.LITTLE_ENDIAN)
                // There are probably a bunch of different/better ways to calculate
                // these two given your circumstances. Cast should be safe since if the WAV is
                // > 4 GB we've already made a terrible mistake.
                .putInt((int) (wav.length() - 8)) // ChunkSize
                .putInt((int) (wav.length() - 44)) // Subchunk2Size
                .array();

        RandomAccessFile accessWave = null;
        //noinspection CaughtExceptionImmediatelyRethrown
        try {
            accessWave = new RandomAccessFile(wav, "rw");
            // ChunkSize
            accessWave.seek(4);
            accessWave.write(sizes, 0, 4);

            // Subchunk2Size
            accessWave.seek(40);
            accessWave.write(sizes, 4, 4);
        } catch (IOException ex) {
            // Rethrow but we still close accessWave in our finally
            throw ex;
        } finally {
            if (accessWave != null) {
                try {
                    accessWave.close();
                } catch (IOException ex) {
                    //
                }
            }
        }
    }

    @Override
    protected void onCancelled(Object[] results) {
        // Handling cancellations and successful runs in the same way
        Log.d("RecordWaveTask", "onCancelled");
        onPostExecute(results);
    }

    @Override
    protected void onPostExecute(Object[] results) {
        Log.d("RecordWaveTask", "onPostExecute");
        Throwable throwable = null;
        if (results[0] instanceof Throwable) {
            // Error
            throwable = (Throwable) results[0];
            Log.e(RecordWaveTask.class.getSimpleName(), throwable.getMessage(), throwable);
        }

        if (cancelCompleteListener != null) {
            cancelCompleteListener.onCancelCompleted();
        }
    }
}