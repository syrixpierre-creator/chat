import mongoose from "mongoose";

const storySchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    mediaUrl: { type: String, required: true },
    caption: { type: String },
    viewedBy: { type: [String], default: [] },
    repostedFromStoryId: { type: String },
    repostedFromUsername: { type: String },
    createdAt: { type: Date, default: Date.now },
    expiresAt: { type: Date, required: true }
  },
  { versionKey: false }
);

export default mongoose.model("Story", storySchema);
