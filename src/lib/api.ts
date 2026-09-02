import { supabase } from "@/integrations/supabase/client";

/* --------------------------------- types --------------------------------- */

export type Profile = {
  id: string;
  user_id: string | null;
  username: string;
  display_name: string;
  bio: string;
  avatar_url: string | null;
  location: string;
  website: string;
  verified: boolean;
  follower_count: number;
  following_count: number;
  created_at: string;
};

export type FeedPost = {
  id: string;
  author: Profile;
  content: string;
  image_gradient: string | null;
  tags: string[];
  likeCount: number;
  commentCount: number;
  repostCount: number;
  viewCount: number;
  created_at: string;
  likedByMe: boolean;
  repostedByMe: boolean;
  bookmarkedByMe: boolean;
};

export type SpaceRow = {
  id: string;
  title: string;
  topic: string;
  listeners: number;
  live: boolean;
  starts_at: string | null;
  gradient: string;
  host: Profile;
};

export type CommentRow = {
  id: string;
  body: string;
  created_at: string;
  author: Profile;
};

export type NotificationRow = {
  id: string;
  type: string;
  body: string;
  read: boolean;
  created_at: string;
  actor: Profile | null;
};

export type ConversationRow = {
  id: string;
  updated_at: string;
  partner: Profile | null;
  preview: string;
  lastAt: string;
};

export type MessageRow = {
  id: string;
  conversation_id: string;
  sender_id: string;
  body: string;
  created_at: string;
};

/* -------------------------------- helpers -------------------------------- */

const POST_SELECT = `id, content, image_gradient, tags, like_count, comment_count, repost_count,
  view_count, created_at, author:profiles!posts_author_id_fkey(*)`;

type RawPost = {
  id: string;
  content: string;
  image_gradient: string | null;
  tags: string[] | null;
  like_count: number;
  comment_count: number;
  repost_count: number;
  view_count: number;
  created_at: string;
  author: Profile;
};

async function viewerSets(viewerId: string | null) {
  if (!viewerId) {
    return { liked: new Set<string>(), reposted: new Set<string>(), saved: new Set<string>() };
  }
  const [likes, reposts, saves] = await Promise.all([
    supabase.from("post_likes").select("post_id").eq("profile_id", viewerId),
    supabase.from("post_reposts").select("post_id").eq("profile_id", viewerId),
    supabase.from("post_bookmarks").select("post_id").eq("profile_id", viewerId),
  ]);
  return {
    liked: new Set((likes.data ?? []).map((r) => r.post_id)),
    reposted: new Set((reposts.data ?? []).map((r) => r.post_id)),
    saved: new Set((saves.data ?? []).map((r) => r.post_id)),
  };
}

function shape(
  rows: RawPost[],
  sets: { liked: Set<string>; reposted: Set<string>; saved: Set<string> },
): FeedPost[] {
  return rows.map((r) => ({
    id: r.id,
    author: r.author,
    content: r.content,
    image_gradient: r.image_gradient,
    tags: r.tags ?? [],
    likeCount: r.like_count,
    commentCount: r.comment_count,
    repostCount: r.repost_count,
    viewCount: r.view_count,
    created_at: r.created_at,
    likedByMe: sets.liked.has(r.id),
    repostedByMe: sets.reposted.has(r.id),
    bookmarkedByMe: sets.saved.has(r.id),
  }));
}

/* --------------------------------- reads --------------------------------- */

export async function fetchPosts(opts: {
  viewerId: string | null;
  authorId?: string;
  ids?: string[];
}): Promise<FeedPost[]> {
  let query = supabase
    .from("posts")
    .select(POST_SELECT)
    .order("created_at", { ascending: false })
    .limit(60);
  if (opts.authorId) query = query.eq("author_id", opts.authorId);
  if (opts.ids) {
    if (opts.ids.length === 0) return [];
    query = query.in("id", opts.ids);
  }
  const [{ data, error }, sets] = await Promise.all([query, viewerSets(opts.viewerId)]);
  if (error) throw error;
  return shape((data ?? []) as unknown as RawPost[], sets);
}

export async function fetchBookmarkedPosts(viewerId: string | null): Promise<FeedPost[]> {
  if (!viewerId) return [];
  const { data, error } = await supabase
    .from("post_bookmarks")
    .select("post_id")
    .eq("profile_id", viewerId);
  if (error) throw error;
  return fetchPosts({ viewerId, ids: (data ?? []).map((r) => r.post_id) });
}

export async function fetchProfiles(): Promise<Profile[]> {
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .order("follower_count", { ascending: false })
    .limit(30);
  if (error) throw error;
  return (data ?? []) as Profile[];
}

export async function fetchProfileByUsername(username: string): Promise<Profile | null> {
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("username", username)
    .maybeSingle();
  if (error) throw error;
  return (data as Profile | null) ?? null;
}

export async function fetchSpaces(): Promise<SpaceRow[]> {
  const { data, error } = await supabase
    .from("spaces")
    .select("id, title, topic, listeners, live, starts_at, gradient, host:profiles!spaces_host_id_fkey(*)")
    .order("live", { ascending: false })
    .order("listeners", { ascending: false });
  if (error) throw error;
  return (data ?? []) as unknown as SpaceRow[];
}

export async function fetchComments(postId: string): Promise<CommentRow[]> {
  const { data, error } = await supabase
    .from("post_comments")
    .select("id, body, created_at, author:profiles!post_comments_author_id_fkey(*)")
    .eq("post_id", postId)
    .order("created_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as unknown as CommentRow[];
}

export async function fetchNotifications(viewerId: string | null): Promise<NotificationRow[]> {
  if (!viewerId) return [];
  const { data, error } = await supabase
    .from("notifications")
    .select("id, type, body, read, created_at, actor:profiles!notifications_actor_id_fkey(*)")
    .eq("recipient_id", viewerId)
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) throw error;
  return (data ?? []) as unknown as NotificationRow[];
}

export async function fetchFollowingIds(viewerId: string | null): Promise<string[]> {
  if (!viewerId) return [];
  const { data, error } = await supabase
    .from("follows")
    .select("following_id")
    .eq("follower_id", viewerId);
  if (error) throw error;
  return (data ?? []).map((r) => r.following_id);
}

export async function fetchConversations(viewerId: string | null): Promise<ConversationRow[]> {
  if (!viewerId) return [];
  const { data: mine, error } = await supabase
    .from("conversation_participants")
    .select("conversation_id")
    .eq("profile_id", viewerId);
  if (error) throw error;
  const ids = (mine ?? []).map((r) => r.conversation_id);
  if (ids.length === 0) return [];

  const [{ data: convos }, { data: parts }, { data: msgs }] = await Promise.all([
    supabase.from("conversations").select("id, updated_at").in("id", ids),
    supabase
      .from("conversation_participants")
      .select("conversation_id, profile:profiles!conversation_participants_profile_id_fkey(*)")
      .in("conversation_id", ids),
    supabase
      .from("messages")
      .select("conversation_id, body, created_at")
      .in("conversation_id", ids)
      .order("created_at", { ascending: false }),
  ]);

  return (convos ?? [])
    .map((c) => {
      const partner =
        ((parts ?? []) as unknown as { conversation_id: string; profile: Profile }[]).find(
          (p) => p.conversation_id === c.id && p.profile?.id !== viewerId,
        )?.profile ?? null;
      const last = (msgs ?? []).find((m) => m.conversation_id === c.id);
      return {
        id: c.id,
        updated_at: c.updated_at,
        partner,
        preview: last?.body ?? "Say hello 👋",
        lastAt: last?.created_at ?? c.updated_at,
      };
    })
    .sort((a, b) => +new Date(b.lastAt) - +new Date(a.lastAt));
}

export async function fetchMessages(conversationId: string): Promise<MessageRow[]> {
  const { data, error } = await supabase
    .from("messages")
    .select("id, conversation_id, sender_id, body, created_at")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as MessageRow[];
}

/* ------------------------------- mutations -------------------------------- */

function extractTags(content: string) {
  return Array.from(content.matchAll(/#(\w{2,30})/g)).map((m) => m[1]!);
}

const GRADIENTS = [
  "from-violet-500 via-fuchsia-500 to-pink-500",
  "from-orange-400 via-rose-400 to-violet-500",
  "from-sky-400 via-cyan-400 to-emerald-400",
  "from-amber-400 via-orange-400 to-rose-500",
];

export async function createPost(input: {
  authorId: string;
  content: string;
  withCover?: boolean;
}) {
  const { error } = await supabase.from("posts").insert({
    author_id: input.authorId,
    content: input.content,
    tags: extractTags(input.content),
    image_gradient: input.withCover
      ? GRADIENTS[Math.floor(Math.random() * GRADIENTS.length)]!
      : null,
    view_count: 1,
  });
  if (error) throw error;
}

export async function deletePost(id: string) {
  const { error } = await supabase.from("posts").delete().eq("id", id);
  if (error) throw error;
}

type ToggleTable = "post_likes" | "post_reposts" | "post_bookmarks";

export async function togglePostRelation(
  table: ToggleTable,
  postId: string,
  profileId: string,
  on: boolean,
) {
  const { error } = on
    ? await supabase.from(table).insert({ post_id: postId, profile_id: profileId })
    : await supabase.from(table).delete().eq("post_id", postId).eq("profile_id", profileId);
  if (error) throw error;
}

export async function toggleFollow(followerId: string, followingId: string, on: boolean) {
  const { error } = on
    ? await supabase.from("follows").insert({ follower_id: followerId, following_id: followingId })
    : await supabase
        .from("follows")
        .delete()
        .eq("follower_id", followerId)
        .eq("following_id", followingId);
  if (error) throw error;
}

export async function addComment(postId: string, authorId: string, body: string) {
  const { error } = await supabase
    .from("post_comments")
    .insert({ post_id: postId, author_id: authorId, body });
  if (error) throw error;
}

export async function notify(input: {
  recipientId: string;
  actorId: string;
  type: string;
  body: string;
}) {
  if (input.recipientId === input.actorId) return;
  await supabase.from("notifications").insert({
    recipient_id: input.recipientId,
    actor_id: input.actorId,
    type: input.type,
    body: input.body,
  });
}

export async function markNotificationsRead(viewerId: string) {
  await supabase
    .from("notifications")
    .update({ read: true })
    .eq("recipient_id", viewerId)
    .eq("read", false);
}

export async function updateProfile(id: string, patch: Partial<Profile>) {
  const { error } = await supabase.from("profiles").update(patch).eq("id", id);
  if (error) throw error;
}

/** Finds an existing 1:1 conversation with `partnerId`, or creates one. */
export async function getOrCreateConversation(viewerId: string, partnerId: string) {
  const { data: mine } = await supabase
    .from("conversation_participants")
    .select("conversation_id")
    .eq("profile_id", viewerId);
  const ids = (mine ?? []).map((r) => r.conversation_id);

  if (ids.length > 0) {
    const { data: theirs } = await supabase
      .from("conversation_participants")
      .select("conversation_id")
      .eq("profile_id", partnerId)
      .in("conversation_id", ids);
    const existing = theirs?.[0]?.conversation_id;
    if (existing) return existing;
  }

  const { data: convo, error } = await supabase
    .from("conversations")
    .insert({})
    .select("id")
    .single();
  if (error) throw error;
  const { error: partErr } = await supabase.from("conversation_participants").insert([
    { conversation_id: convo.id, profile_id: viewerId },
    { conversation_id: convo.id, profile_id: partnerId },
  ]);
  if (partErr) throw partErr;
  return convo.id;
}

export async function sendMessage(conversationId: string, senderId: string, body: string) {
  const { error } = await supabase
    .from("messages")
    .insert({ conversation_id: conversationId, sender_id: senderId, body });
  if (error) throw error;
}
