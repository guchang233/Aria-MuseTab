// SPDX-License-Identifier: AGPL-3.0-only
// Adapted from Andromr d800585; all native tensors are scoped to this job.
package aria.skip.omr;

import java.nio.FloatBuffer;
import java.util.HashMap;
import ai.onnxruntime.*;

public final class Staff2Score {
    private LiteRTModel encoder;
    private OrtEnvironment environment;
    private OrtSession decoder;
    private static final int LAYERS = 32, MAX_LENGTH = 608;

    public void load(String encoderPath, String decoderPath, String threads) throws Exception {
        encoder = new LiteRTModel();
        try {
            encoder.load(encoderPath, Integer.parseInt(threads));
            environment = OrtEnvironment.getEnvironment();
            try (OrtSession.SessionOptions options = new OrtSession.SessionOptions()) {
                options.setIntraOpNumThreads(Integer.parseInt(threads));
                options.setInterOpNumThreads(1);
                decoder = environment.createSession(decoderPath, options);
            }
        } catch (Exception error) { unload_model(); throw error; }
    }
    public long[][] run(FloatBuffer image) throws Exception { return decode(encoder.runFloat(image)); }

    public long[][] decode(float[] encoded) throws OrtException {
        long[][] tokens = new long[6][MAX_LENGTH];
        long[] previous = {1, 0, 0, 0, 0, 0};
        OnnxTensor[] emptyCaches = new OnnxTensor[LAYERS];
        OrtSession.Result previousResult = null;
        try (OnnxTensor context = OnnxTensor.createTensor(environment, FloatBuffer.wrap(encoded), new long[]{1,1280,512});
             OnnxTensor emptyContext = OnnxTensor.createTensor(environment, FloatBuffer.wrap(new float[0]), new long[]{1,0,512})) {
            for (int i=0; i<LAYERS; i++) emptyCaches[i] = OnnxTensor.createTensor(environment, FloatBuffer.wrap(new float[0]), new long[]{1,8,0,64});
            for (int step=0; step<MAX_LENGTH; step++) {
                if (Thread.currentThread().isInterrupted()) throw new IllegalStateException("识别已取消");
                String[] inputs = {"rhythms", "lifts", "pitchs", "articulations", "positions", "slurs"};
                String[] outputs = {"out_rhythms", "out_lifts", "out_pitchs", "out_articulations", "out_positions", "out_slurs"};
                HashMap<String, OnnxTensor> feed = new HashMap<>();
                OnnxTensor[] current = new OnnxTensor[6];
                OrtSession.Result next = null;
                try {
                    for (int i=0; i<6; i++) {
                        if (i == 4) continue; // positions are output-only in this model.
                        current[i] = OnnxTensor.createTensor(environment, new long[][]{{previous[i]}});
                        feed.put(inputs[i], current[i]);
                    }
                    current[4] = OnnxTensor.createTensor(environment, new long[]{step});
                    feed.put("cache_len", current[4]);
                    feed.put("context", step == 0 ? context : emptyContext);
                    for (int i=0; i<LAYERS; i++) feed.put("cache_in"+i, previousResult == null ? emptyCaches[i]
                        : (OnnxTensor) previousResult.get("cache_out"+i).get());
                    next = decoder.run(feed);
                    if (previousResult != null) { previousResult.close(); previousResult = null; }
                    for (int i=0; i<6; i++) {
                        previous[i] = ((long[]) next.get(outputs[i]).get().getValue())[0];
                        tokens[i][step] = previous[i]+1;
                    }
                    if (previous[0] == 2) { next.close(); next = null; break; }
                    previousResult = next; next = null;
                } finally {
                    for (OnnxTensor tensor : current) if (tensor != null) tensor.close();
                    if (next != null) next.close();
                }
            }
        } finally {
            if (previousResult != null) previousResult.close();
            for (OnnxTensor tensor : emptyCaches) if (tensor != null) tensor.close();
        }
        return tokens;
    }
    public void unload_model() throws OrtException {
        if (encoder != null) { encoder.close(); encoder = null; }
        if (decoder != null) { decoder.close(); decoder = null; }
    }
}
