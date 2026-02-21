import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get the authorization header
    const authHeader = req.headers.get("Authorization");
    console.log("Auth header present:", !!authHeader);

    if (!authHeader) {
      throw new Error("Missing authorization header");
    }

    // Extract the JWT token (remove "Bearer " prefix if present)
    const token = authHeader.replace("Bearer ", "");

    // Create admin client to verify the JWT
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Verify the user using the token
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError) {
      console.error("Auth error:", userError);
      throw new Error(`Authentication failed: ${userError.message}`);
    }

    if (!user) {
      throw new Error("Not authenticated");
    }

    const userId = user.id;
    console.log(`Processing account deletion for user: ${userId}`);

    // Get user's pair_id to clean up partner references
    const { data: userData } = await supabaseAdmin
      .from("users")
      .select("pair_id")
      .eq("id", userId)
      .single();

    const userPairId = userData?.pair_id;

    // If paired, clear partner's pair_id
    if (userPairId) {
      console.log(`Clearing partner's pair_id for pair: ${userPairId}`);
      await supabaseAdmin
        .from("users")
        .update({ pair_id: null, invite_code: null })
        .eq("pair_id", userPairId)
        .neq("id", userId);
    }

    // Delete user's location data
    console.log("Deleting user locations...");
    await supabaseAdmin.from("user_locations").delete().eq("user_id", userId);

    // Delete sticky note replies by this user
    console.log("Deleting sticky note replies...");
    await supabaseAdmin.from("sticky_note_replies").delete().eq("author_id", userId);

    // Delete sticky note likes by this user
    console.log("Deleting sticky note likes...");
    await supabaseAdmin.from("sticky_note_likes").delete().eq("user_id", userId);

    // Get user's sticky notes to delete associated data
    const { data: userNotes } = await supabaseAdmin
      .from("sticky_notes")
      .select("id")
      .eq("author_id", userId);

    if (userNotes && userNotes.length > 0) {
      const noteIds = userNotes.map(n => n.id);
      console.log(`Deleting data for ${noteIds.length} user notes...`);

      // Delete replies on user's notes
      await supabaseAdmin.from("sticky_note_replies").delete().in("note_id", noteIds);

      // Delete likes on user's notes
      await supabaseAdmin.from("sticky_note_likes").delete().in("note_id", noteIds);

      // Delete the notes themselves
      await supabaseAdmin.from("sticky_notes").delete().in("id", noteIds);
    }

    // Get user's folders to delete folder images first
    const { data: userFolders } = await supabaseAdmin
      .from("wallpaper_folders")
      .select("id")
      .eq("user_id", userId);

    if (userFolders && userFolders.length > 0) {
      const folderIds = userFolders.map(f => f.id);
      console.log(`Deleting images for ${folderIds.length} folders...`);

      // Delete folder images
      await supabaseAdmin.from("folder_images").delete().in("folder_id", folderIds);

      // Delete folders
      await supabaseAdmin.from("wallpaper_folders").delete().in("id", folderIds);
    }

    // Delete wallpapers
    console.log("Deleting wallpapers...");
    await supabaseAdmin.from("wallpapers").delete().eq("user_id", userId);

    // Delete shared board photos
    console.log("Deleting shared board photos...");
    await supabaseAdmin.from("shared_board_photos").delete().eq("uploader_id", userId);

    // Delete reported content by this user
    console.log("Deleting reported content...");
    await supabaseAdmin.from("reported_content").delete().eq("reporter_id", userId);

    // =========================================================================
    // Storage cleanup - delete all files uploaded by this user
    // =========================================================================
    console.log("Cleaning up storage files...");

    // Files are stored as {userId}/{filename} in the 'wallpapers' bucket
    try {
      // List all files in the user's folder
      const { data: userFiles, error: listError } = await supabaseAdmin.storage
        .from("wallpapers")
        .list(userId);

      if (listError) {
        console.error("Error listing user files:", listError);
      } else if (userFiles && userFiles.length > 0) {
        // Build array of file paths to delete
        const filePaths = userFiles.map(file => `${userId}/${file.name}`);
        console.log(`Deleting ${filePaths.length} files from storage...`);

        const { error: deleteError } = await supabaseAdmin.storage
          .from("wallpapers")
          .remove(filePaths);

        if (deleteError) {
          console.error("Error deleting storage files:", deleteError);
        } else {
          console.log(`Successfully deleted ${filePaths.length} storage files`);
        }
      } else {
        console.log("No storage files found for user");
      }
    } catch (storageError) {
      // Don't fail the whole deletion if storage cleanup fails
      console.error("Storage cleanup error (non-fatal):", storageError);
    }

    // Delete the user record from users table
    console.log("Deleting user record...");
    await supabaseAdmin.from("users").delete().eq("id", userId);

    // Finally, delete from auth.users using admin API
    console.log("Deleting auth user...");
    const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (deleteAuthError) {
      console.error("Error deleting auth user:", deleteAuthError);
      throw new Error(`Failed to delete auth user: ${deleteAuthError.message}`);
    }

    console.log(`Successfully deleted account for user: ${userId}`);

    return new Response(
      JSON.stringify({ success: true, message: "Account deleted successfully" }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  } catch (error) {
    console.error("Error deleting account:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  }
});
