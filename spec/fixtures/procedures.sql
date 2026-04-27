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

-- FOUND-preservation fixtures: these functions check that FOUND retains
-- its value after piggly instrumentation calls.

-- Case 1: EXCEPTION handler with NO_DATA_FOUND followed by IF NOT FOUND
CREATE OR REPLACE FUNCTION public.test_found_exception(p_key integer)
  RETURNS text AS $$
DECLARE
  result integer;
BEGIN
  BEGIN
    SELECT 1 INTO STRICT result FROM generate_series(1,0) WHERE false;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
  END;

  IF NOT FOUND THEN
    RETURN 'not_found_branch';
  ELSE
    RETURN 'found_branch';
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Case 2: PERFORM on a void function inside a block, then checking FOUND
-- after a query that returns no rows (FOUND should be FALSE)
CREATE OR REPLACE FUNCTION public.test_found_after_no_rows()
  RETURNS text AS $$
DECLARE
  result integer;
BEGIN
  SELECT 1 INTO result FROM generate_series(1,0) WHERE false;
  IF NOT FOUND THEN
    RETURN 'not_found_branch';
  ELSE
    RETURN 'found_branch';
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Case 3: PERFORM on a void function inside a block, then checking FOUND
-- after a query that returns rows (FOUND should be TRUE)
CREATE OR REPLACE FUNCTION public.test_found_after_rows()
  RETURNS text AS $$
DECLARE
  result integer;
BEGIN
  SELECT 1 INTO result FROM generate_series(1,1);
  IF FOUND THEN
    RETURN 'found_branch';
  ELSE
    RETURN 'not_found_branch';
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Case 4: WHILE loop that doesn't execute, followed by IF NOT FOUND
-- The exit stub `perform piggly_cond(..., false)` fires after the loop
-- and sets FOUND=TRUE (piggly_cond returns a row), corrupting the
-- FOUND status from a prior no-rows query.
CREATE OR REPLACE FUNCTION public.test_found_while_zero_iterations()
  RETURNS text AS $$
DECLARE
  result integer;
BEGIN
  SELECT 1 INTO result FROM generate_series(1,0) WHERE false;
  -- FOUND is FALSE here

  WHILE false LOOP
    result := 1;
  END LOOP;
  -- After the loop, piggly inserts: perform piggly_cond(..., false);
  -- which sets FOUND=TRUE, corrupting the FALSE from the SELECT above

  IF NOT FOUND THEN
    RETURN 'not_found_branch';
  ELSE
    RETURN 'found_branch';
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Case 5: FOR loop with zero iterations, followed by IF NOT FOUND check.
-- PostgreSQL sets FOUND=FALSE when FOR executes 0 iterations.
-- The old piggly_cond exit stub (perform) would corrupt FOUND to TRUE.
CREATE OR REPLACE FUNCTION public.test_found_for_loop()
  RETURNS text AS $$
DECLARE
  result integer;
  i integer;
BEGIN
  SELECT 1 INTO result FROM generate_series(1,0) WHERE false;
  -- FOUND is FALSE here

  FOR i IN 1..0 LOOP
    NULL;
  END LOOP;
  -- 0 iterations → PostgreSQL sets FOUND=FALSE
  -- Old piggly exit stub (perform piggly_cond) would set FOUND=TRUE here

  IF NOT FOUND THEN
    RETURN 'not_found_branch';
  ELSE
    RETURN 'found_branch';
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Case 6: WHILE loop that executes, prior query returned rows, FOUND should stay TRUE.
-- The body stub `perform piggly_cond(..., true)` returns a row so FOUND=TRUE,
-- but the exit stub `perform piggly_cond(..., false)` also returns a row → FOUND=TRUE.
-- Here FOUND should remain TRUE (from the SELECT), but exit stub still corrupts
-- by always setting FOUND=TRUE regardless of original value.
-- This case PASSES by accident, but is included for completeness.
CREATE OR REPLACE FUNCTION public.test_found_while_after_rows()
  RETURNS text AS $$
DECLARE
  result integer;
  i integer := 0;
BEGIN
  SELECT 1 INTO result FROM generate_series(1,1);
  -- FOUND is TRUE here

  WHILE i < 1 LOOP
    i := i + 1;
  END LOOP;
  -- piggly exit stub: perform piggly_cond(..., false) → FOUND=TRUE (by accident correct)

  IF FOUND THEN
    RETURN 'found_branch';
  ELSE
    RETURN 'not_found_branch';
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;
