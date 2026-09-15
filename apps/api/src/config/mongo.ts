import mongoose from "mongoose";

export async function connectMongo() {
  mongoose.set("bufferCommands", false);
  const uri = process.env.MONGO_URI;
  if (!uri) {
    console.warn("[AI Studio] MONGO_URI not provided — database running in offline/mock mode");
    return null;
  }
  try {
    await mongoose.connect(uri);
    return mongoose.connection;
  } catch (err) {
    console.warn("[AI Studio] MongoDB connection failed — continuing with offline fallback:", err);
    return null;
  }
}
