-- Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender TEXT NOT NULL,
    subject TEXT DEFAULT '',
    body TEXT NOT NULL,
    snippet TEXT DEFAULT '',
    category TEXT NOT NULL DEFAULT 'not_spam', -- 'spam', 'sus', 'not_spam'
    risk_percentage INT DEFAULT 0,
    status_description TEXT DEFAULT '',
    reasons TEXT[] DEFAULT '{}',
    masked_links TEXT[] DEFAULT '{}',
    is_read BOOLEAN DEFAULT false,
    is_blocked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Allow anon and authenticated users to SELECT, INSERT, UPDATE, DELETE
CREATE POLICY "Allow public read access" ON public.messages FOR SELECT USING (true);
CREATE POLICY "Allow public insert access" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update access" ON public.messages FOR UPDATE USING (true);
CREATE POLICY "Allow public delete access" ON public.messages FOR DELETE USING (true);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
