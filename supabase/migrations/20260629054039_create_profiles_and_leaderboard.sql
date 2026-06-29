/*
# Create profiles and leaderboard tables

## Summary
Adds two tables to support Google sign-in and a public score leaderboard.

## New Tables

### profiles
Stores display info for signed-in users, synced from Google OAuth.
- id (uuid, PK, references auth.users)
- display_name (text) – the user's Google display name
- avatar_url (text, nullable) – Google profile picture URL
- created_at / updated_at (timestamptz)

### leaderboard
Stores individual game results submitted by signed-in players.
- id (uuid, PK)
- user_id (uuid, FK auth.users, NOT NULL DEFAULT auth.uid())
- display_name / avatar_url – denormalized snapshot so leaderboard reads stay fast
- mode (text) – 'daily' or 'practice'
- score (integer 0-20) – remaining guesses at game end; higher = better
- guesses_used (integer 0-20)
- won (boolean)
- date (text, nullable) – YYYY-MM-DD; set only for daily mode
- played_at (timestamptz)

## Security

### profiles
- RLS enabled.
- SELECT: anon + authenticated (public read so leaderboard can show avatars).
- INSERT/UPDATE: authenticated users can only write their own row.

### leaderboard
- RLS enabled.
- SELECT: anon + authenticated (anyone can view the leaderboard).
- INSERT: authenticated users can only insert rows where user_id = auth.uid().
  The DEFAULT auth.uid() on the column ensures omitting user_id in the insert works.

## Indexes
- leaderboard(mode, date, won, score DESC) – fast daily/practice leaderboard queries.
- Partial unique index on (user_id, date) WHERE mode='daily' – one daily entry per user per day.
*/

CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select" ON profiles;
CREATE POLICY "profiles_select" ON profiles FOR SELECT
TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "profiles_insert" ON profiles;
CREATE POLICY "profiles_insert" ON profiles FOR INSERT
TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update" ON profiles;
CREATE POLICY "profiles_update" ON profiles FOR UPDATE
TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE TABLE IF NOT EXISTS leaderboard (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL,
  avatar_url text,
  mode text NOT NULL CHECK (mode IN ('daily', 'practice')),
  score integer NOT NULL CHECK (score >= 0 AND score <= 20),
  guesses_used integer NOT NULL CHECK (guesses_used >= 0 AND guesses_used <= 20),
  won boolean NOT NULL DEFAULT false,
  date text,
  played_at timestamptz DEFAULT now()
);

ALTER TABLE leaderboard ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "leaderboard_select" ON leaderboard;
CREATE POLICY "leaderboard_select" ON leaderboard FOR SELECT
TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "leaderboard_insert" ON leaderboard;
CREATE POLICY "leaderboard_insert" ON leaderboard FOR INSERT
TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS leaderboard_mode_date_idx
  ON leaderboard(mode, date, won, score DESC);

CREATE UNIQUE INDEX IF NOT EXISTS leaderboard_user_daily_unique
  ON leaderboard(user_id, date)
  WHERE mode = 'daily' AND date IS NOT NULL;
