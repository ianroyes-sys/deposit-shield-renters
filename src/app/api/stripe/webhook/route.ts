import { NextResponse, type NextRequest } from "next/server";
import Stripe from "stripe";
import { createServiceRoleClient } from "@/lib/supabase/server";
import { env, isStripeConfigured, isStripeWebhookConfigured } from "@/lib/env";

export async function POST(request: NextRequest) {
  if (!isStripeConfigured || !isStripeWebhookConfigured) {
    return NextResponse.json(
      { error: "Stripe webhook is not configured on this deployment." },
      { status: 501 }
    );
  }

  const stripe = new Stripe(env.stripeSecretKey);
  const body = await request.text();
  const signature = request.headers.get("stripe-signature");

  if (!signature) {
    return NextResponse.json({ error: "Missing signature" }, { status: 400 });
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, env.stripeWebhookSecret);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Invalid signature";
    return NextResponse.json({ error: `Webhook signature verification failed: ${message}` }, { status: 400 });
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as Stripe.Checkout.Session;
    const propertyId = session.metadata?.property_id;
    if (propertyId) {
      const supabase = createServiceRoleClient();
      await supabase
        .from("properties")
        .update({ is_paid: true, stripe_session_id: session.id })
        .eq("id", propertyId);
    }
  }

  return NextResponse.json({ received: true });
}
