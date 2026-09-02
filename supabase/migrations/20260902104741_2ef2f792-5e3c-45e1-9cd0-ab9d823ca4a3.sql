-- helper that only reads publicly-readable profiles: no elevated rights needed
CREATE OR REPLACE FUNCTION public.my_profile_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  SELECT id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1
$$;

-- trigger-only functions must not be callable through the API
REVOKE ALL ON FUNCTION public.bump_post_counter() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.bump_follow_counters() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.touch_conversation() FROM PUBLIC, anon, authenticated;

-- membership check stays elevated (it must bypass RLS to avoid recursion) but is
-- restricted to signed-in callers only
REVOKE ALL ON FUNCTION public.is_conversation_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_conversation_member(uuid) TO authenticated;