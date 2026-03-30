require "spec_helper"

module Piggly
  module Dumper

    describe "ReifiedProcedure (integration)" do
      include_context "with database"

      # -----------------------------------------------------------------------
      describe ".all" do

        it "returns ReifiedProcedure instances" do
          procs = ReifiedProcedure.all(conn)
          expect(procs).to all(be_a(ReifiedProcedure))
        end

        it "includes fixture function test_branches" do
          names = ReifiedProcedure.all(conn).map{|p| p.name.to_s }
          expect(names).to include("public.test_branches")
        end

        it "includes fixture function test_loop" do
          names = ReifiedProcedure.all(conn).map{|p| p.name.to_s }
          expect(names).to include("public.test_loop")
        end

        it "excludes pg_catalog procedures" do
          names = ReifiedProcedure.all(conn).map{|p| p.name.schema }
          expect(names).not_to include("pg_catalog")
        end

        it "excludes information_schema procedures" do
          names = ReifiedProcedure.all(conn).map{|p| p.name.schema }
          expect(names).not_to include("information_schema")
        end

        context "piggly_% name filter (Bug B regression)" do
          it "excludes public.piggly_audit (support-like name in public schema)" do
            # public.piggly_audit should be excluded because it's in public with piggly_ prefix —
            # but this is a FUTURE desired state after the bug fix makes it schema-aware.
            # For now we document the current (buggy) behaviour: it IS excluded.
            names = ReifiedProcedure.all(conn).map{|p| p.name.to_s }
            # After Bug B fix this expectation should be changed to include("public.piggly_audit")
            pending "Bug B: piggly_% filter is name-only; public.piggly_audit is excluded even though it is a user procedure"
            expect(names).to include("public.piggly_audit")
          end

          it "does not exclude piggly_helper functions installed by install_support" do
            # After install_support, piggly_cond etc. should still be absent from all()
            installer = Installer.new(config, conn)
            profile   = Profile.new
            installer.send(:install_support, profile)

            names = ReifiedProcedure.all(conn).map{|p| p.name.to_s }
            expect(names).not_to include("public.piggly_cond")
            expect(names).not_to include("public.piggly_branch")
          ensure
            installer.send(:uninstall_support)
          end
        end

        it "returns correct return type for test_branches" do
          p = ReifiedProcedure.all(conn).find{|p| p.name.to_s == "public.test_branches" }
          expect(p.type.to_s).to eq("text")
        end

        it "returns correct argument type for test_branches" do
          p = ReifiedProcedure.all(conn).find{|p| p.name.to_s == "public.test_branches" }
          # format_type() returns 'integer' for the pg internal name
          expect(p.arg_types.first.to_s).to eq("integer")
        end

        it "returns correct volatility for test_branches" do
          p = ReifiedProcedure.all(conn).find{|p| p.name.to_s == "public.test_branches" }
          expect(p.volatility).to eq("volatile")
        end
      end

      # -----------------------------------------------------------------------
      describe "#source + #store_source" do

        let(:procedure) do
          ReifiedProcedure.all(conn).find{|p| p.name.to_s == "public.test_branches" }
        end

        it "source returns the procedure body as a String" do
          expect(procedure.source(config)).to include("RETURN 'positive'")
        end

        it "store_source writes source to disk" do
          procedure.store_source(config)
          expect(File.exist?(procedure.source_path(config))).to be true
        end

        it "source matches load_source after store_source" do
          procedure.store_source(config)
          expect(procedure.source(config)).to eq(procedure.load_source(config))
        end

        it "raises when source already contains $PIGGLY$ markers" do
          # Simulate already-instrumented source
          bad_proc = ReifiedProcedure.new(
            "BEGIN perform public.piggly_cond($PIGGLY$abc$PIGGLY$, true); END",
            procedure.oid,
            procedure.name,
            procedure.strict,
            procedure.secdef,
            procedure.setof,
            procedure.type,
            procedure.volatility,
            procedure.arg_modes,
            procedure.arg_names,
            procedure.arg_types,
            Array.new(procedure.arg_types.length)
          )
          expect { bad_proc.store_source(config) }.to raise_error(/already instrumented/)
        end
      end

      # -----------------------------------------------------------------------
      describe "#skeleton" do

        let(:procedure) do
          ReifiedProcedure.all(conn).find{|p| p.name.to_s == "public.test_branches" }
        end

        it "returns a SkeletonProcedure" do
          expect(procedure.skeleton).to be_a(SkeletonProcedure)
        end

        it "skeleton has the same oid" do
          expect(procedure.skeleton.oid).to eq(procedure.oid)
        end

        it "skeleton has the same name" do
          expect(procedure.skeleton.name.to_s).to eq(procedure.name.to_s)
        end

        it "skeleton? returns false on ReifiedProcedure" do
          expect(procedure.skeleton?).to be false
        end

        it "skeleton? returns true on the resulting SkeletonProcedure" do
          expect(procedure.skeleton.skeleton?).to be true
        end
      end

      # -----------------------------------------------------------------------
      describe "encoding" do

        let(:loop_proc) do
          ReifiedProcedure.all(conn).find{|p| p.name.to_s == "public.test_loop" }
        end

        it "retrieves UTF-8 procedure source with no encoding error" do
          expect { loop_proc.source(config).encode("UTF-8") }.not_to raise_error
        end

        it "source contains the UTF-8 comment from the fixture" do
          expect(loop_proc.source(config).encode("UTF-8")).to include("Ošetření")
        end

        it "store_source + load_source preserves UTF-8 bytes exactly" do
          loop_proc.store_source(config)
          reloaded = loop_proc.load_source(config)
          expect(reloaded.encode("UTF-8")).to eq(loop_proc.source(config).encode("UTF-8"))
        end
      end

    end

  end
end
