import { redis } from "../config/redis.js";
import nodemailer from "nodemailer";

const VERIFICATION_TTL_SECONDS = 60 * 15;

export function generateVerificationCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export async function storeVerificationCode(email: string, code: string) {
  await redis.set(`verify:${email}`, code, "EX", VERIFICATION_TTL_SECONDS);
}

export async function checkVerificationCode(email: string, code: string) {
  const stored = await redis.get(`verify:${email}`);
  if (!stored || stored !== code) return false;
  await redis.del(`verify:${email}`);
  return true;
}

function buildTransport() {
  if (!process.env.GMAIL_USER || !process.env.GMAIL_APP_PASSWORD) {
    return null;
  }
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: process.env.GMAIL_USER,
      pass: process.env.GMAIL_APP_PASSWORD
    }
  });
}

export async function sendVerificationEmail(toEmail: string, code: string) {
  const transport = buildTransport();
  if (!transport) {
    console.log(`[email:dev] code de verification pour ${toEmail}: ${code}`);
    return;
  }
  await transport.sendMail({
    from: `SYRIX CHAT <${process.env.GMAIL_USER}>`,
    to: toEmail,
    subject: "Verify your SYRIX CHAT account",
    text: `Your verification code is ${code}`
  });
}
