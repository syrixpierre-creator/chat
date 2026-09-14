import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    type: { type: String, enum: ["mention", "contact_added", "reaction", "gift"], required: true },
    actorId: { type: String, required: true },
    conversationId: { type: String },
    messageId: { type: String },
    text: { type: String },
    read: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now }
  },
  { versionKey: false }
);

export default mongoose.model("Notification", notificationSchema);
