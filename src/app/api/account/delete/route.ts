import { NextRequest, NextResponse } from "next/server";
import { createClient, createServiceRoleClient } from "@/lib/supabase/server";
import { isServiceRoleConfigured } from "@/lib/env";

export async function POST(request: NextRequest) {
  // Native apps authenticate with a bearer access token instead of the
  // browser session cookie.
  const authHeader = request.headers.get("authorization");
  const bearerToken = authHeader?.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : null;

  const supabase = await createClient();
  const {
    data: { user },
  } = bearerToken
    ? await supabase.auth.getUser(bearerToken)
    : await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Not signed in" }, { status: 401 });
  }

  if (!isServiceRoleConfigured) {
    return NextResponse.json(
      { error: "Account deletion needs SUPABASE_SECRET_KEY configured on the server." },
      { status: 501 }
    );
  }

  const admin = createServiceRoleClient();

  const { data: properties } = await admin
    .from("properties")
    .select("id")
    .eq("user_id", user.id);

  const propertyIds = (properties ?? []).map((p: { id: string }) => p.id);

  if (propertyIds.length > 0) {
    const { data: photos } = await admin
      .from("photos")
      .select("storage_path")
      .in("property_id", propertyIds);
    const photoPaths = (photos ?? []).map((p: { storage_path: string }) => p.storage_path);
    if (photoPaths.length > 0) {
      await admin.storage.from("photos").remove(photoPaths);
    }

    const { data: reports } = await admin
      .from("reports")
      .select("storage_path")
      .in("property_id", propertyIds);
    const reportPaths = (reports ?? [])
      .map((r: { storage_path: string | null }) => r.storage_path)
      .filter((p: string | null): p is string => !!p);
    if (reportPaths.length > 0) {
      await admin.storage.from("reports").remove(reportPaths);
    }
  }

  // Cascading foreign keys clean up rooms/photos/reports when properties are deleted.
  await admin.from("properties").delete().eq("user_id", user.id);
  await admin.auth.admin.deleteUser(user.id);

  const response = NextResponse.json({ deleted: true });
  await supabase.auth.signOut();
  return response;
}
