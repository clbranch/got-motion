-- Photo library images can exceed the old 2 MB cap, which the storage API
-- rejects mid-upload and surfaces on the client as a broken pipe. Clients now
-- downscale to JPEG first; this raises the ceiling so a large source image
-- fails loudly rather than killing the connection.

UPDATE storage.buckets
SET file_size_limit = 10485760
WHERE id IN ('avatars', 'group-avatars');
