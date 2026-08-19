-- Brogrammers Fitness predates creator tracking. Assign the account explicitly
-- approved by the product owner, provided it is already a group member.

UPDATE public.groups AS g
SET created_by = p.id
FROM public.profiles AS p
WHERE g.name = 'Brogrammers Fitness'
  AND g.created_by IS NULL
  AND lower(p.email) = 'chrisloganbranch@gmail.com'
  AND EXISTS (
    SELECT 1
    FROM public.group_members AS gm
    WHERE gm.group_id = g.id
      AND gm.user_id = p.id
  );
