import { NextResponse, type NextRequest } from "next/server";
import Stripe from "stripe";
import { createClient } from "@/lib/supabase/server";
import { env, isStripeConfigured, PROPERTY_PRICE_USD } from "@/lib/env";

export async function POST(request: NextRequest) {
  if (!isStripeConfigured) {
    return NextResponse.json(
      { error: "Stripe isn't configured on this deployment. Use the dev unlock instead." },
      { status: 400 }
    );
  }

  const { propertyId } = await request.json();
  if (!propertyId) {
    return NextResponse.json({ error: "Missing propertyId" }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Not signed in" }, { status: 401 });
  }

  const { data: property } = await supabase
    .from("properties")
    .select("id, nickname, address_line1, is_paid")
    .eq("id", propertyId)
    .eq("user_id", user.id)
    .maybeSingle();

  if (!property) {
    return NextResponse.json({ error: "Property not found" }, { status: 404 });
  }

  const stripe = new Stripe(env.stripeSecretKey);

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    payment_method_types: ["card"],
    line_items: [
      {
        price_data: {
          currency: "usd",
          unit_amount: PROPERTY_PRICE_USD * 100,
          product_data: {
            name: `Deposit Shield — ${property.nickname || property.address_line1 || "Property"}`,
            description: "Unlimited photos, full condition report, and evidence packet for this property.",
          },
        },
        quantity: 1,
      },
    ],
    metadata: { property_id: property.id, user_id: user.id },
    success_url: `${env.appUrl}/checkout/success?property_id=${property.id}`,
    cancel_url: `${env.appUrl}/checkout/cancel?property_id=${property.id}`,
  });

  return NextResponse.json({ url: session.url });
}
