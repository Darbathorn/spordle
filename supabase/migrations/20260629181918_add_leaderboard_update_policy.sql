-- Allow authenticated users to update their own leaderboard rows
-- (needed so profile name/avatar changes propagate to existing entries)
DROP POLICY IF EXISTS "leaderboard_update" ON leaderboard;
CREATE POLICY "leaderboard_update" ON leaderboard FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
