-- ============ profiles ============
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE,
  username text NOT NULL UNIQUE,
  display_name text NOT NULL,
  bio text NOT NULL DEFAULT '',
  avatar_url text,
  location text NOT NULL DEFAULT '',
  website text NOT NULL DEFAULT '',
  verified boolean NOT NULL DEFAULT false,
  follower_count integer NOT NULL DEFAULT 0,
  following_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.profiles TO anon;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_public_read" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.my_profile_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1
$$;
GRANT EXECUTE ON FUNCTION public.my_profile_id() TO authenticated, anon;

-- ============ posts ============
CREATE TABLE public.posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  image_gradient text,
  tags text[] NOT NULL DEFAULT '{}',
  like_count integer NOT NULL DEFAULT 0,
  comment_count integer NOT NULL DEFAULT 0,
  repost_count integer NOT NULL DEFAULT 0,
  view_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX posts_created_at_idx ON public.posts (created_at DESC);
GRANT SELECT ON public.posts TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.posts TO authenticated;
GRANT ALL ON public.posts TO service_role;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "posts_public_read" ON public.posts FOR SELECT USING (true);
CREATE POLICY "posts_insert_own" ON public.posts FOR INSERT TO authenticated WITH CHECK (author_id = public.my_profile_id());
CREATE POLICY "posts_update_own" ON public.posts FOR UPDATE TO authenticated USING (author_id = public.my_profile_id()) WITH CHECK (author_id = public.my_profile_id());
CREATE POLICY "posts_delete_own" ON public.posts FOR DELETE TO authenticated USING (author_id = public.my_profile_id());

-- ============ likes / reposts / bookmarks ============
CREATE TABLE public.post_likes (
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, profile_id)
);
GRANT SELECT ON public.post_likes TO anon;
GRANT SELECT, INSERT, DELETE ON public.post_likes TO authenticated;
GRANT ALL ON public.post_likes TO service_role;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "likes_public_read" ON public.post_likes FOR SELECT USING (true);
CREATE POLICY "likes_insert_own" ON public.post_likes FOR INSERT TO authenticated WITH CHECK (profile_id = public.my_profile_id());
CREATE POLICY "likes_delete_own" ON public.post_likes FOR DELETE TO authenticated USING (profile_id = public.my_profile_id());

CREATE TABLE public.post_reposts (
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, profile_id)
);
GRANT SELECT ON public.post_reposts TO anon;
GRANT SELECT, INSERT, DELETE ON public.post_reposts TO authenticated;
GRANT ALL ON public.post_reposts TO service_role;
ALTER TABLE public.post_reposts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reposts_public_read" ON public.post_reposts FOR SELECT USING (true);
CREATE POLICY "reposts_insert_own" ON public.post_reposts FOR INSERT TO authenticated WITH CHECK (profile_id = public.my_profile_id());
CREATE POLICY "reposts_delete_own" ON public.post_reposts FOR DELETE TO authenticated USING (profile_id = public.my_profile_id());

CREATE TABLE public.post_bookmarks (
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, profile_id)
);
GRANT SELECT, INSERT, DELETE ON public.post_bookmarks TO authenticated;
GRANT ALL ON public.post_bookmarks TO service_role;
ALTER TABLE public.post_bookmarks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "bookmarks_own_read" ON public.post_bookmarks FOR SELECT TO authenticated USING (profile_id = public.my_profile_id());
CREATE POLICY "bookmarks_insert_own" ON public.post_bookmarks FOR INSERT TO authenticated WITH CHECK (profile_id = public.my_profile_id());
CREATE POLICY "bookmarks_delete_own" ON public.post_bookmarks FOR DELETE TO authenticated USING (profile_id = public.my_profile_id());

-- ============ comments ============
CREATE TABLE public.post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX post_comments_post_idx ON public.post_comments (post_id, created_at);
GRANT SELECT ON public.post_comments TO anon;
GRANT SELECT, INSERT, DELETE ON public.post_comments TO authenticated;
GRANT ALL ON public.post_comments TO service_role;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "comments_public_read" ON public.post_comments FOR SELECT USING (true);
CREATE POLICY "comments_insert_own" ON public.post_comments FOR INSERT TO authenticated WITH CHECK (author_id = public.my_profile_id());
CREATE POLICY "comments_delete_own" ON public.post_comments FOR DELETE TO authenticated USING (author_id = public.my_profile_id());

-- ============ follows ============
CREATE TABLE public.follows (
  follower_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CONSTRAINT follows_no_self CHECK (follower_id <> following_id)
);
GRANT SELECT ON public.follows TO anon;
GRANT SELECT, INSERT, DELETE ON public.follows TO authenticated;
GRANT ALL ON public.follows TO service_role;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "follows_public_read" ON public.follows FOR SELECT USING (true);
CREATE POLICY "follows_insert_own" ON public.follows FOR INSERT TO authenticated WITH CHECK (follower_id = public.my_profile_id());
CREATE POLICY "follows_delete_own" ON public.follows FOR DELETE TO authenticated USING (follower_id = public.my_profile_id());

-- ============ spaces ============
CREATE TABLE public.spaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  host_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  topic text NOT NULL DEFAULT 'General',
  listeners integer NOT NULL DEFAULT 0,
  live boolean NOT NULL DEFAULT false,
  starts_at timestamptz,
  gradient text NOT NULL DEFAULT 'from-violet-500 to-fuchsia-500',
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.spaces TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.spaces TO authenticated;
GRANT ALL ON public.spaces TO service_role;
ALTER TABLE public.spaces ENABLE ROW LEVEL SECURITY;
CREATE POLICY "spaces_public_read" ON public.spaces FOR SELECT USING (true);
CREATE POLICY "spaces_insert_own" ON public.spaces FOR INSERT TO authenticated WITH CHECK (host_id = public.my_profile_id());
CREATE POLICY "spaces_update_own" ON public.spaces FOR UPDATE TO authenticated USING (host_id = public.my_profile_id()) WITH CHECK (host_id = public.my_profile_id());
CREATE POLICY "spaces_delete_own" ON public.spaces FOR DELETE TO authenticated USING (host_id = public.my_profile_id());

-- ============ conversations ============
CREATE TABLE public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.conversation_participants (
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (conversation_id, profile_id)
);
CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX messages_conversation_idx ON public.messages (conversation_id, created_at);

GRANT SELECT, INSERT, UPDATE ON public.conversations TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.conversation_participants TO authenticated;
GRANT SELECT, INSERT ON public.messages TO authenticated;
GRANT ALL ON public.conversations, public.conversation_participants, public.messages TO service_role;

CREATE OR REPLACE FUNCTION public.is_conversation_member(_conversation_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_participants cp
    JOIN public.profiles p ON p.id = cp.profile_id
    WHERE cp.conversation_id = _conversation_id AND p.user_id = auth.uid()
  )
$$;
GRANT EXECUTE ON FUNCTION public.is_conversation_member(uuid) TO authenticated;

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conversations_member_read" ON public.conversations FOR SELECT TO authenticated USING (public.is_conversation_member(id));
CREATE POLICY "conversations_insert" ON public.conversations FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "conversations_member_update" ON public.conversations FOR UPDATE TO authenticated USING (public.is_conversation_member(id)) WITH CHECK (public.is_conversation_member(id));

CREATE POLICY "participants_member_read" ON public.conversation_participants FOR SELECT TO authenticated USING (public.is_conversation_member(conversation_id));
CREATE POLICY "participants_insert" ON public.conversation_participants FOR INSERT TO authenticated WITH CHECK (profile_id = public.my_profile_id() OR public.is_conversation_member(conversation_id));
CREATE POLICY "participants_delete_self" ON public.conversation_participants FOR DELETE TO authenticated USING (profile_id = public.my_profile_id());

CREATE POLICY "messages_member_read" ON public.messages FOR SELECT TO authenticated USING (public.is_conversation_member(conversation_id));
CREATE POLICY "messages_insert_own" ON public.messages FOR INSERT TO authenticated WITH CHECK (sender_id = public.my_profile_id() AND public.is_conversation_member(conversation_id));

-- ============ notifications ============
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  type text NOT NULL,
  body text NOT NULL,
  read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_recipient_idx ON public.notifications (recipient_id, created_at DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notifications_own_read" ON public.notifications FOR SELECT TO authenticated USING (recipient_id = public.my_profile_id());
CREATE POLICY "notifications_insert" ON public.notifications FOR INSERT TO authenticated WITH CHECK (actor_id = public.my_profile_id());
CREATE POLICY "notifications_own_update" ON public.notifications FOR UPDATE TO authenticated USING (recipient_id = public.my_profile_id()) WITH CHECK (recipient_id = public.my_profile_id());
CREATE POLICY "notifications_own_delete" ON public.notifications FOR DELETE TO authenticated USING (recipient_id = public.my_profile_id());

-- ============ counter triggers ============
CREATE OR REPLACE FUNCTION public.bump_post_counter()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  col text := TG_ARGV[0];
  delta integer := CASE WHEN TG_OP = 'INSERT' THEN 1 ELSE -1 END;
  target uuid := CASE WHEN TG_OP = 'INSERT' THEN NEW.post_id ELSE OLD.post_id END;
BEGIN
  EXECUTE format('UPDATE public.posts SET %I = GREATEST(%I + $1, 0) WHERE id = $2', col, col)
  USING delta, target;
  RETURN NULL;
END;
$$;

CREATE TRIGGER post_likes_counter AFTER INSERT OR DELETE ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION public.bump_post_counter('like_count');
CREATE TRIGGER post_reposts_counter AFTER INSERT OR DELETE ON public.post_reposts
  FOR EACH ROW EXECUTE FUNCTION public.bump_post_counter('repost_count');
CREATE TRIGGER post_comments_counter AFTER INSERT OR DELETE ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION public.bump_post_counter('comment_count');

CREATE OR REPLACE FUNCTION public.bump_follow_counters()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.profiles SET follower_count = follower_count + 1 WHERE id = NEW.following_id;
    UPDATE public.profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
  ELSE
    UPDATE public.profiles SET follower_count = GREATEST(follower_count - 1, 0) WHERE id = OLD.following_id;
    UPDATE public.profiles SET following_count = GREATEST(following_count - 1, 0) WHERE id = OLD.follower_id;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER follows_counter AFTER INSERT OR DELETE ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.bump_follow_counters();

CREATE OR REPLACE FUNCTION public.touch_conversation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.conversations SET updated_at = now() WHERE id = NEW.conversation_id;
  RETURN NULL;
END;
$$;
CREATE TRIGGER messages_touch_conversation AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.touch_conversation();

-- ============ realtime ============
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;

-- ============ demo content ============
INSERT INTO public.profiles (id, username, display_name, bio, location, website, verified, follower_count, following_count) VALUES
  ('11111111-1111-4111-8111-000000000001', 'clarawrites', 'Clara Meyer', 'Essays on attention, craft, and slow internet.', 'Berlin, DE', 'clara.ink', true, 42310, 512),
  ('11111111-1111-4111-8111-000000000002', 'marcusfilm', 'Marcus Bell', 'Cinematographer. Golden hour obsessive.', 'Los Angeles, US', 'marcus.film', true, 88120, 220),
  ('11111111-1111-4111-8111-000000000003', 'yuki', 'Yuki Tanaka', 'Spatial computing, tiny robots, big diagrams.', 'Tokyo, JP', 'yuki.dev', false, 30470, 190),
  ('11111111-1111-4111-8111-000000000004', 'diegom', 'Diego Márquez', 'Sound designer. Field recordings from everywhere.', 'Mexico City, MX', 'diego.audio', false, 15600, 640),
  ('11111111-1111-4111-8111-000000000005', 'priyas', 'Priya Sharma', 'Product engineer. Shipping small things daily.', 'Bengaluru, IN', 'priya.sh', true, 21900, 410),
  ('11111111-1111-4111-8111-000000000006', 'lumen', 'Lumen HQ', 'Building a calmer place to share what you love.', 'Everywhere', 'lumen.social', true, 128400, 12);

INSERT INTO public.posts (id, author_id, content, image_gradient, tags, like_count, comment_count, repost_count, view_count, created_at) VALUES
  ('22222222-2222-4222-8222-000000000001', '11111111-1111-4111-8111-000000000001', 'Spent the morning rewriting a paragraph eleven times. The eleventh one took forty seconds. The first ten were the price of admission.', NULL, ARRAY['writing','craft'], 1284, 96, 212, 48200, now() - interval '8 minutes'),
  ('22222222-2222-4222-8222-000000000002', '11111111-1111-4111-8111-000000000002', 'Shot this one entirely on a 40-year-old lens. Every flaw in the glass became part of the frame. Sometimes the imperfection is the look.', 'from-orange-400 via-rose-400 to-violet-500', ARRAY['GoldenHour','photography'], 5310, 244, 880, 194000, now() - interval '42 minutes'),
  ('22222222-2222-4222-8222-000000000003', '11111111-1111-4111-8111-000000000003', 'Prototype note: spatial UI stops feeling like magic the moment latency crosses 90ms. Everything after that is just physics you can feel.', NULL, ARRAY['SpatialComputing'], 2044, 158, 401, 77400, now() - interval '2 hours'),
  ('22222222-2222-4222-8222-000000000004', '11111111-1111-4111-8111-000000000004', 'Recorded a thunderstorm from inside a parked car at 3am. Pitched it down two octaves and it became the calmest thing I own.', 'from-sky-400 via-cyan-400 to-emerald-400', ARRAY['sounddesign'], 932, 61, 143, 28900, now() - interval '4 hours'),
  ('22222222-2222-4222-8222-000000000005', '11111111-1111-4111-8111-000000000005', 'Shipped a 12-line change that removed a 400-line abstraction. Best week of the quarter and nobody will ever notice. That is the job.', NULL, ARRAY['engineering'], 3611, 187, 622, 121000, now() - interval '7 hours'),
  ('22222222-2222-4222-8222-000000000006', '11111111-1111-4111-8111-000000000006', 'New design system pass: fewer shadows, one accent, real motion curves. The interface finally feels like it breathes.', 'from-violet-500 via-fuchsia-500 to-pink-500', ARRAY['LumenDesign','design'], 1876, 132, 298, 64300, now() - interval '12 hours');

INSERT INTO public.post_comments (post_id, author_id, body, created_at) VALUES
  ('22222222-2222-4222-8222-000000000001', '11111111-1111-4111-8111-000000000005', 'The eleventh draft always reads like the first idea. Wild how that works.', now() - interval '5 minutes'),
  ('22222222-2222-4222-8222-000000000002', '11111111-1111-4111-8111-000000000004', 'That falloff on the left edge is unreal.', now() - interval '30 minutes'),
  ('22222222-2222-4222-8222-000000000006', '11111111-1111-4111-8111-000000000001', 'The motion curves alone are worth the rewrite.', now() - interval '9 hours');

INSERT INTO public.spaces (title, host_id, topic, listeners, live, starts_at, gradient) VALUES
  ('Designing for calm: interfaces that do not shout', '11111111-1111-4111-8111-000000000006', 'Design', 1842, true, NULL, 'from-violet-500 to-fuchsia-500'),
  ('Shooting golden hour without golden hour', '11111111-1111-4111-8111-000000000002', 'Photography', 964, true, NULL, 'from-orange-500 to-rose-500'),
  ('Latency is the whole product', '11111111-1111-4111-8111-000000000003', 'Technology', 0, false, now() + interval '2 hours', 'from-sky-500 to-cyan-500'),
  ('Field recording clinic: bring your worst audio', '11111111-1111-4111-8111-000000000004', 'Audio', 0, false, now() + interval '1 day', 'from-emerald-500 to-teal-500');