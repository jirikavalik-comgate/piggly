require 'spec_helper'

module Piggly

  describe Compiler::CoverageReport do
    let(:config)    { double("config") }
    let(:report)    { Compiler::CoverageReport.new(config) }
    let(:trace)     { instance_double(Compiler::TraceCompiler) }
    let(:procedure) { double("procedure", name: double(to_s: "public.test")) }

    before do
      allow(Compiler::TraceCompiler).to receive(:new).with(config).and_return(trace)
    end

    describe "compile" do
      context "delegates to TraceCompiler with recompile: false" do
        before do
          allow(procedure).to receive(:source).with(config).and_return("BEGIN\nEND;")
        end

        it "calls trace compile with recompile: false" do
          tree = N.terminal("hello", tagged?: false, style: nil)
          expect(trace).to receive(:compile).with(procedure, recompile: false).and_return({tree: tree})
          report.compile(procedure, {})
        end
      end

      context "when trace cache is fresh" do
        # Build simple mock nodes using the N helper from spec_helper
        let(:tag_id)  { "abcd1234ef567890" }
        let(:tag)     { instance_double(Tags::EvaluationTag,
                          complete?: true, style: "c1", id: tag_id, description: "full") }
        let(:profile) { {tag_id => tag} }

        before do
          allow(procedure).to receive(:source).with(config).and_return("BEGIN\nEND;")
        end

        it "recurses the children of non-terminal node" do
          child = N.terminal("hello", tagged?: false, style: nil)
          tree  = N.sequence(child)
          allow(trace).to receive(:compile).with(procedure, recompile: false).and_return({tree: tree})
          result = report.compile(procedure, profile)
          expect(result[:html]).to include("hello")
        end

        it "does not recurse terminal nodes" do
          tree = N.terminal("leaf_text", tagged?: false, style: nil)
          allow(trace).to receive(:compile).with(procedure, recompile: false).and_return({tree: tree})
          result = report.compile(procedure, profile)
          expect(result[:html]).to eq("leaf_text")
        end

        it "marks tagged terminal nodes" do
          tree = N.terminal("stmt", tagged?: true, tag_id: tag_id, style: nil)
          allow(trace).to receive(:compile).with(procedure, recompile: false).and_return({tree: tree})
          result = report.compile(procedure, profile)
          expect(result[:html]).to include(%[id="T#{tag_id}"])
          expect(result[:html]).to include("stmt")
        end

        it "does not mark untagged terminal nodes" do
          tree = N.terminal("stmt", tagged?: false, style: nil)
          allow(trace).to receive(:compile).with(procedure, recompile: false).and_return({tree: tree})
          result = report.compile(procedure, profile)
          expect(result[:html]).not_to include("<span")
          expect(result[:html]).to eq("stmt")
        end

        it "marks tagged non-terminal nodes" do
          inner = N.terminal("body", tagged?: false, style: nil)
          tree  = N.new(tagged?: true, tag_id: tag_id,
                        terminal?: false, style: nil,
                        elements: [inner])
          allow(trace).to receive(:compile).with(procedure, recompile: false).and_return({tree: tree})
          result = report.compile(procedure, profile)
          expect(result[:html]).to include(%[id="T#{tag_id}"])
        end

        it "does not mark untagged non-terminal nodes" do
          inner = N.terminal("body", tagged?: false, style: nil)
          tree  = N.new(tagged?: false, terminal?: false, style: nil, elements: [inner])
          allow(trace).to receive(:compile).with(procedure, recompile: false).and_return({tree: tree})
          result = report.compile(procedure, profile)
          expect(result[:html]).not_to include(%[id="T])
          expect(result[:html]).to include("body")
        end
      end
    end
  end

end
