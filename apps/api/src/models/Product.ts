import mongoose from "mongoose";

const productSchema = new mongoose.Schema(
  {
    ownerId: { type: String, required: true, index: true },
    name: { type: String, required: true },
    description: { type: String },
    price: { type: Number, default: 0 },
    imageUrl: { type: String },
    launchDate: { type: Date },
    createdAt: { type: Date, default: Date.now }
  },
  { versionKey: false }
);

export default mongoose.model("Product", productSchema);
