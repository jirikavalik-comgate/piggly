-- Test fixture procedures for piggly integration tests.
-- Main fixtures use names NOT starting with piggly_ so they work with
-- both the old and fixed code. The piggly_% Bug B fixture is in a separate
-- schema to demonstrate that the filter incorrectly excludes it.

-- Covers: IF/ELSIF/ELSE -> ConditionalBranchTag (true + false paths)
CREATE OR REPLACE FUNCTION public.test_branches(x integer)
  RETURNS text AS $$
BEGIN
  IF x > 0 THEN
    RETURN 'positive';
  ELSIF x < 0 THEN
    RETURN 'negative';
  ELSE
    RETURN 'zero';
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Covers: WHILE loop -> ConditionalLoopTag (pass-through, once, twice+)
-- The function body contains a UTF-8 comment to exercise encoding round-trips.
CREATE OR REPLACE FUNCTION public.test_loop(n integer)
  RETURNS integer AS $$
DECLARE
  -- Ošetření výjimky — zpracování smyčky
  i   integer := 0;
  acc integer := 0;
BEGIN
  WHILE i < n LOOP
    acc := acc + i;
    i   := i + 1;
  END LOOP;
  RETURN acc;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Bug B fixture: a function whose name starts with piggly_ but lives in
-- a user schema (piggly_test_ns). After the Bug B fix, all() should include
-- it because the piggly_% exclusion should only apply to the public schema.
CREATE SCHEMA IF NOT EXISTS piggly_test_ns;
CREATE OR REPLACE FUNCTION piggly_test_ns.piggly_audit(x integer)
  RETURNS integer AS $$
BEGIN
  RETURN x;
END;
$$ LANGUAGE plpgsql VOLATILE;
