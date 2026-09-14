import mongoose from "mongoose";

const liveChatMessageSchema = new mongoose.Schema(
  {
    liveId: { type: String, required: true, index: true },
    senderId: { type: String, required: true },
    senderUsername: { type: String, required: true },
    content: { type: String, required: true },
    createdAt: { type: Date, default: Date.now }
  },
  { versionKey: false }
);

export default mongoose.model("LiveChatMessage", liveChatMessageSchema);
