import mongoose from "mongoose";

const liveSessionSchema = new mongoose.Schema(
  {
    hostId: { type: String, required: true, index: true },
    title: { type: String, required: true },
    status: { type: String, enum: ["live", "ended"], default: "live" },
    viewerCount: { type: Number, default: 0 },
    giftTotal: { type: Number, default: 0 },
    startedAt: { type: Date, default: Date.now },
    endedAt: { type: Date }
  },
  { versionKey: false }
);

export default mongoose.model("LiveSession", liveSessionSchema);
