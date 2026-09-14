import mongoose from "mongoose";

const memberStatsSchema = new mongoose.Schema(
  {
    conversationId: { type: String, required: true, index: true },
    userId: { type: String, required: true },
    xp: { type: Number, default: 0 },
    lastXpAt: { type: Date },
    createdAt: { type: Date, default: Date.now }
  },
  { versionKey: false }
);

memberStatsSchema.index({ conversationId: 1, userId: 1 }, { unique: true });

export default mongoose.model("MemberStats", memberStatsSchema);
