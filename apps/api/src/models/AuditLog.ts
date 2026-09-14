import mongoose from "mongoose";

const auditLogSchema = new mongoose.Schema(
  {
    conversationId: { type: String, required: true, index: true },
    actorId: { type: String, required: true },
    action: {
      type: String,
      enum: [
        "promote",
        "demote",
        "kick",
        "ban",
        "transfer_ownership",
        "closed_group_on",
        "closed_group_off",
        "moderation_on",
        "moderation_off"
      ],
      required: true
    },
    targetId: { type: String },
    createdAt: { type: Date, default: Date.now }
  },
  { versionKey: false }
);

export default mongoose.model("AuditLog", auditLogSchema);
