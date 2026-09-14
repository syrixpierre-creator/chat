import mongoose from "mongoose";

export async function connectMongo() {
  const uri = process.env.MONGO_URI || "mongodb://localhost:27017/syrix_chat";
  await mongoose.connect(uri);
  return mongoose.connection;
}
