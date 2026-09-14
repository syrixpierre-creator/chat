import mongoose from "mongoose";

const noteSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    content: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now }
  },
  { versionKey: false }
);

export default mongoose.model("Note", noteSchema);
