import Stripe from "stripe";

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "sk_test_replace_me", {
  apiVersion: "2024-06-20"
});

export const WALLET_PACKAGES = [
  { id: "pack_5", amountUsd: 5, credits: 500 },
  { id: "pack_10", amountUsd: 10, credits: 1100 },
  { id: "pack_25", amountUsd: 25, credits: 2900 },
  { id: "pack_50", amountUsd: 50, credits: 6000 }
];

export const PREMIUM_PACKAGE = { id: "premium_month", amountUsd: 4.99, days: 30 };
