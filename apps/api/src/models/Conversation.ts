import mongoose from "mongoose";

const conversationSchema = new mongoose.Schema(
  {
    type: { type: String, enum: ["private", "group", "community"], default: "private" },
    communityId: { type: String, index: true },
    unreadBy: { type: [String], default: [] },
    archivedBy: { type: [String], default: [] },
    lastAutoReplyAt: { type: Date },
    name: { type: String },
    avatarUrl: { type: String },
    description: { type: String },
    participantIds: { type: [String], required: true, index: true },
    creatorId: { type: String },
    isPrivate: { type: Boolean, default: true },
    inviteCode: { type: String, unique: true, sparse: true },
    messagePrice: { type: Number, default: 0 },
    selfDestructSeconds: { type: Number, default: 0 },
    aiModerationEnabled: { type: Boolean, default: false },
    adminIds: { type: [String], default: [] },
    bannedUserIds: { type: [String], default: [] },
    closedGroup: { type: Boolean, default: false },
    whoCanAddGroups: { type: String, enum: ["admins", "everyone"], default: "admins" },
    whoCanSendMessages: { type: String, enum: ["admins", "everyone"], default: "everyone" },
    whoCanEditInfo: { type: String, enum: ["admins", "everyone"], default: "everyone" },
    whoCanAddMembers: { type: String, enum: ["admins", "everyone"], default: "everyone" },
    approveNewMembers: { type: Boolean, default: false },
    lastMessage: {
      content: { type: String },
      senderId: { type: String },
      createdAt: { type: Date }
    },
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now }
  },
  { versionKey: false }
);

export default mongoose.model("Conversation", conversationSchema);
