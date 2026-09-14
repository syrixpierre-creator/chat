import mongoose from "mongoose";

const chatFolderSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    name: { type: String, required: true },
    conversationIds: { type: [String], default: [] },
    createdAt: { type: Date, default: Date.now }
  },
  { versionKey: false }
);

export default mongoose.model("ChatFolder", chatFolderSchema);
