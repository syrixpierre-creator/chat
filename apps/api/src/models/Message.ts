import mongoose from "mongoose";

const messageSchema = new mongoose.Schema(
  {
    conversationId: { type: String, required: true, index: true },
    senderId: { type: String, required: true },
    type: { type: String, enum: ["text", "voice", "media", "image", "gift"], default: "text" },
    content: { type: String },
    durationSeconds: { type: Number },
    pinned: { type: Boolean, default: false },
    spoiler: { type: Boolean, default: false },
    reactions: {
      type: [{ userId: { type: String, required: true }, emoji: { type: String, required: true } }],
      default: []
    },
    replyTo: {
      messageId: { type: String },
      senderId: { type: String },
      content: { type: String },
      type: { type: String }
    },
    deletedFor: { type: [String], default: [] },
    deletedForEveryone: { type: Boolean, default: false },
    edited: { type: Boolean, default: false },
    editedAt: { type: Date },
    expireAt: { type: Date },
    createdAt: { type: Date, default: Date.now }
  },
  { versionKey: false }
);

messageSchema.index({ expireAt: 1 }, { expireAfterSeconds: 0 });

export default mongoose.model("Message", messageSchema);
