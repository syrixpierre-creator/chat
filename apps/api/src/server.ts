import "dotenv/config";
import express from "express";
import cors from "cors";
import { connectMongo } from "./config/mongo.js";
import { redis } from "./config/redis.js";
import authRoutes from "./routes/authRoutes.js";
import userRoutes from "./routes/userRoutes.js";
import chatRoutes from "./routes/chatRoutes.js";
import storyRoutes from "./routes/storyRoutes.js";
import messageRoutes from "./routes/messageRoutes.js";
import liveRoutes from "./routes/liveRoutes.js";
import walletRoutes from "./routes/walletRoutes.js";
import setupRoutes from "./routes/setupRoutes.js";
import adminRoutes from "./routes/adminRoutes.js";
import contactRoutes from "./routes/contactRoutes.js";
import uploadRoutes from "./routes/uploadRoutes.js";
import giftRoutes from "./routes/giftRoutes.js";
import callRoutes from "./routes/callRoutes.js";
import botRoutes from "./routes/botRoutes.js";
import noteRoutes from "./routes/noteRoutes.js";
import folderRoutes from "./routes/folderRoutes.js";
import notificationRoutes from "./routes/notificationRoutes.js";
import catalogRoutes from "./routes/catalogRoutes.js";
import { handleStripeWebhook } from "./controllers/walletController.js";
import { setupWebSocketServer } from "./ws/index.js";
import { UPLOADS_DIR } from "./config/upload.js";
import http from "http";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ADMIN_DIR = path.join(__dirname, "..", "public", "admin");

const app = express();

app.use(cors({ origin: process.env.APP_DOMAIN || "*" }));

app.post(
  "/api/wallet/webhook",
  express.raw({ type: "application/json" }),
  handleStripeWebhook
);

app.use(express.json());

app.get("/health", async (req, res) => {
  res.json({ status: "ok", app: "SYRIX CHAT API" });
});

app.get("/wallet/success", (req, res) => {
  res.send("<h1>Payment successful</h1><p>You can return to the SYRIX CHAT app.</p>");
});

app.get("/wallet/cancel", (req, res) => {
  res.send("<h1>Payment cancelled</h1><p>You can return to the SYRIX CHAT app.</p>");
});

app.use("/uploads", express.static(UPLOADS_DIR));
app.use("/downloads", express.static(path.join(__dirname, "..", "public", "downloads")));

app.use("/api/auth", authRoutes);
app.use("/api/users", userRoutes);
app.use("/api/chats", chatRoutes);
app.use("/api/chats", messageRoutes);
app.use("/api/stories", storyRoutes);
app.use("/api/live", liveRoutes);
app.use("/api/wallet", walletRoutes);
app.use("/api/setup", setupRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/contacts", contactRoutes);
app.use("/api/uploads", uploadRoutes);
app.use("/api/gifts", giftRoutes);
app.use("/api/calls", callRoutes);
app.use("/api/bots", botRoutes);
app.use("/api/notes", noteRoutes);
app.use("/api/folders", folderRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/catalog", catalogRoutes);

app.use("/admin", express.static(ADMIN_DIR));
app.get("/admin/*", (req, res) => {
  res.sendFile(path.join(ADMIN_DIR, "index.html"));
});

const LEGAL_DIR = path.join(__dirname, "..", "public", "legal");
app.use("/legal", express.static(LEGAL_DIR));
app.get("/privacy", (req, res) => res.redirect("/legal/privacy.html"));
app.get("/terms", (req, res) => res.redirect("/legal/terms.html"));

app.get("/u/:username", async (req, res) => {
  const { prisma } = await import("./config/postgres.js");
  const user = await prisma.user.findUnique({ where: { username: req.params.username } });

  if (!user || user.profileVisibility !== "everyone") {
    return res.status(404).send("Profile not found");
  }

  const avatar = user.avatarUrl || "";
  res.set("Content-Type", "text/html");
  return res.send(`<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>@${user.username} · SYRIX CHAT</title></head>
<body style="margin:0;font-family:sans-serif;background:#0F172A;color:#F1F5F9;display:flex;align-items:center;justify-content:center;min-height:100vh;">
<div style="text-align:center;padding:32px;">
${avatar ? `<img src="${avatar}" style="width:96px;height:96px;border-radius:50%;object-fit:cover;" />` : ""}
<h2 style="margin:16px 0 4px;">@${user.username}</h2>
${user.bio ? `<p style="color:#94A3B8;max-width:320px;">${user.bio}</p>` : ""}
<a href="syrixchat://profile/${user.username}" style="display:inline-block;margin-top:20px;padding:12px 24px;background:#6C5CE7;color:white;border-radius:999px;text-decoration:none;">Ouvrir dans SYRIX CHAT</a>
</div>
</body></html>`);
});

app.get("/live/:liveId", async (req, res) => {
  const { default: LiveSession } = await import("./models/LiveSession.js");
  const { prisma } = await import("./config/postgres.js");
  const live = await LiveSession.findById(req.params.liveId).lean();

  if (!live || live.status !== "live") {
    return res.status(404).send("This live has ended");
  }

  const host = await prisma.user.findUnique({ where: { id: live.hostId } });
  res.set("Content-Type", "text/html");
  return res.send(`<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${live.title} · SYRIX CHAT LIVE</title></head>
<body style="margin:0;font-family:sans-serif;background:#13111C;color:#F1F5F9;display:flex;align-items:center;justify-content:center;min-height:100vh;">
<div style="text-align:center;padding:32px;">
<span style="display:inline-block;padding:4px 10px;background:#EF4444;border-radius:6px;font-size:12px;font-weight:700;">LIVE</span>
<h2 style="margin:16px 0 4px;">${live.title}</h2>
<p style="color:#9B95B3;">@${host?.username || "unknown"}</p>
<a href="syrixchat://live/${live._id}" style="display:inline-block;margin-top:20px;padding:12px 24px;background:#6C5CE7;color:white;border-radius:999px;text-decoration:none;">Ouvrir dans SYRIX CHAT</a>
</div>
</body></html>`);
});

const PORT = process.env.PORT || 3000;

async function start() {
  await connectMongo();
  await redis.ping();
  const httpServer = http.createServer(app);
  setupWebSocketServer(httpServer);
  httpServer.listen(PORT, () => {
    console.log(`SYRIX CHAT API listening on port ${PORT}`);
    console.log(`WebSocket available at ws://localhost:${PORT}/ws`);
    if (!process.env.LIVEKIT_URL || process.env.LIVEKIT_URL.includes("localhost")) {
      console.warn(
        "WARNING: LIVEKIT_URL is not set or still points to localhost. " +
          "Every call/live attempt from a real phone will fail to connect " +
          "(\"Could not connect to the live stream\") because the phone will " +
          "try to reach itself instead of this server. Set LIVEKIT_URL in " +
          ".env to ws://<this server's public IP or domain>:7880 (or wss:// " +
          "behind a reverse proxy) and restart."
      );
    }
    if (!process.env.GMAIL_USER) {
      console.warn(
        "NOTE: GMAIL_USER is not set. Signup OTP codes will only appear in " +
          "these server logs, not by email."
      );
    }
  });
}

start().catch((err) => {
  console.error("Startup failed", err);
  process.exit(1);
});
