import { Request, Response } from "express";
import { stripe, WALLET_PACKAGES, PREMIUM_PACKAGE } from "../config/stripe.js";
import { prisma } from "../config/postgres.js";
import { AuthedRequest } from "../middleware/auth.js";

export async function listPackages(req: AuthedRequest, res: Response) {
  return res.json(WALLET_PACKAGES);
}

export async function getBalance(req: AuthedRequest, res: Response) {
  return res.json({ walletBalance: req.user!.walletBalance });
}

export async function listTransactions(req: AuthedRequest, res: Response) {
  const transactions = await prisma.walletTransaction.findMany({
    where: { userId: req.user!.id },
    orderBy: { createdAt: "desc" },
    take: 50
  });
  return res.json(transactions);
}

export async function createCheckoutSession(req: AuthedRequest, res: Response) {
  const { packageId } = req.body;
  const selectedPackage = WALLET_PACKAGES.find((p) => p.id === packageId);

  if (!selectedPackage) {
    return res.status(400).json({ error: "invalid_package" });
  }

  const publicUrl = process.env.PUBLIC_API_URL || "http://localhost:4000";

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    payment_method_types: ["card"],
    line_items: [
      {
        price_data: {
          currency: "usd",
          product_data: { name: `SYRIX CHAT — ${selectedPackage.credits} credits` },
          unit_amount: selectedPackage.amountUsd * 100
        },
        quantity: 1
      }
    ],
    metadata: {
      userId: req.user!.id,
      credits: String(selectedPackage.credits)
    },
    success_url: `${publicUrl}/wallet/success`,
    cancel_url: `${publicUrl}/wallet/cancel`
  });

  return res.status(201).json({ url: session.url });
}

export async function createPremiumCheckoutSession(req: AuthedRequest, res: Response) {
  const publicUrl = process.env.PUBLIC_API_URL || "http://localhost:4000";

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    payment_method_types: ["card"],
    line_items: [
      {
        price_data: {
          currency: "usd",
          product_data: { name: "SYRIX CHAT — Premium (30 days)" },
          unit_amount: Math.round(PREMIUM_PACKAGE.amountUsd * 100)
        },
        quantity: 1
      }
    ],
    metadata: {
      userId: req.user!.id,
      premiumDays: String(PREMIUM_PACKAGE.days)
    },
    success_url: `${publicUrl}/wallet/success`,
    cancel_url: `${publicUrl}/wallet/cancel`
  });

  return res.status(201).json({ url: session.url });
}

export async function handleStripeWebhook(req: Request, res: Response) {
  const signature = req.headers["stripe-signature"] as string;

  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET || ""
    );
  } catch (err) {
    console.error("Stripe webhook signature verification failed", err);
    return res.status(400).send("invalid_signature");
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as any;
    const userId = session.metadata?.userId;
    const credits = Number(session.metadata?.credits || 0);
    const premiumDays = Number(session.metadata?.premiumDays || 0);

    if (userId && credits > 0) {
      await prisma.user.update({
        where: { id: userId },
        data: { walletBalance: { increment: credits } }
      });

      await prisma.walletTransaction.create({
        data: {
          userId,
          type: "topup",
          amount: credits
        }
      });
    }

    if (userId && premiumDays > 0) {
      const current = await prisma.user.findUnique({ where: { id: userId } });
      const base =
        current?.premiumExpiresAt && current.premiumExpiresAt > new Date()
          ? current.premiumExpiresAt
          : new Date();
      const newExpiry = new Date(base.getTime() + premiumDays * 24 * 60 * 60 * 1000);
      await prisma.user.update({
        where: { id: userId },
        data: { isPremium: true, premiumExpiresAt: newExpiry }
      });
    }
  }

  return res.json({ received: true });
}
