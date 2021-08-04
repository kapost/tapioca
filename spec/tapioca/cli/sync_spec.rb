# typed: true
# frozen_string_literal: true

require "cli_spec"

module Tapioca
  class SyncSpec < CliSpec
    describe("#sync") do
      before do
        execute("init")
      end

      it "must show a deprecation warning at top and at bottom" do
        output = execute("sync")

        assert_includes(output, <<~OUTPUT)
          DEPRECATION: The `sync` command will be removed in a future release.

          Start using the `gem` command with no arguments instead.

        OUTPUT

        assert_includes(output, <<~OUTPUT)

          DEPRECATION: The `sync` command will be removed in a future release.

          Start using the `gem` command with no arguments instead.
        OUTPUT
      end

      it "must perform no operations if everything is up-to-date" do
        execute("generate")

        output = execute("sync")

        refute_includes(output, "-- Removing:")
        refute_includes(output, "++ Adding:")
        refute_includes(output, "-> Moving:")

        assert_includes(output, <<~OUTPUT)
          Removing RBI files of gems that have been removed:

            Nothing to do.
        OUTPUT
        assert_includes(output, <<~OUTPUT)
          Generating RBI files of gems that are added or updated:

            Nothing to do.
        OUTPUT

        assert_path_exists("#{outdir}/foo@0.0.1.rbi")
        assert_path_exists("#{outdir}/bar@0.3.0.rbi")
        assert_path_exists("#{outdir}/baz@0.0.2.rbi")
      end

      it "generate an empty RBI file" do
        output = execute("sync")

        assert_includes(output, "++ Adding: #{outdir}/qux@0.5.0.rbi\n")
        assert_includes(output, <<~OUTPUT)
          Compiling qux, this may take a few seconds...   Done (empty output)
        OUTPUT

        assert_equal(<<~CONTENTS.chomp, File.read("#{outdir}/qux@0.5.0.rbi"))
          # DO NOT EDIT MANUALLY
          # This is an autogenerated file for types exported from the `qux` gem.
          # Please instead update this file by running `bin/tapioca sync`.

          # typed: true

          # THIS IS AN EMPTY RBI FILE.
          # see https://github.com/Shopify/tapioca/blob/master/README.md#manual-gem-requires

        CONTENTS
      end

      it "generate an empty RBI file without header" do
        execute("sync", "--no-file-header")

        assert_equal(<<~CONTENTS.chomp, File.read("#{outdir}/qux@0.5.0.rbi"))
          # typed: true

          # THIS IS AN EMPTY RBI FILE.
          # see https://github.com/Shopify/tapioca/blob/master/README.md#manual-gem-requires

        CONTENTS
      end

      it "must respect exclude option" do
        execute("generate")

        output = execute("sync", "", exclude: "foo bar")

        assert_includes(output, "-- Removing: #{outdir}/foo@0.0.1.rbi\n")
        assert_includes(output, "-- Removing: #{outdir}/bar@0.3.0.rbi\n")
        refute_includes(output, "-- Removing: #{outdir}/baz@0.0.2.rbi\n")
        refute_includes(output, "++ Adding:")
        refute_includes(output, "-> Moving:")

        refute_includes(output, <<~OUTPUT)
          Removing RBI files of gems that have been removed:

            Nothing to do.
        OUTPUT
        assert_includes(output, <<~OUTPUT)
          Generating RBI files of gems that are added or updated:

            Nothing to do.
        OUTPUT

        refute_path_exists("#{outdir}/foo@0.0.1.rbi")
        refute_path_exists("#{outdir}/bar@0.3.0.rbi")
        assert_path_exists("#{outdir}/baz@0.0.2.rbi")
      end

      it "must remove outdated RBIs" do
        execute("generate")
        FileUtils.touch("#{outdir}/outdated@5.0.0.rbi")

        output = execute("sync")

        assert_includes(output, "-- Removing: #{outdir}/outdated@5.0.0.rbi\n")
        refute_includes(output, "++ Adding:")
        refute_includes(output, "-> Moving:")

        assert_includes(output, <<~OUTPUT)
          Generating RBI files of gems that are added or updated:

            Nothing to do.
        OUTPUT

        assert_path_exists("#{outdir}/foo@0.0.1.rbi")
        assert_path_exists("#{outdir}/bar@0.3.0.rbi")
        assert_path_exists("#{outdir}/baz@0.0.2.rbi")
        refute_path_exists("#{outdir}/outdated@5.0.0.rbi")
      end

      it "must add missing RBIs" do
        ["foo@0.0.1.rbi"].each do |rbi|
          FileUtils.touch("#{outdir}/#{rbi}")
        end

        output = execute("sync")

        assert_includes(output, "++ Adding: #{outdir}/bar@0.3.0.rbi\n")
        assert_includes(output, "++ Adding: #{outdir}/baz@0.0.2.rbi\n")
        refute_includes(output, "-- Removing:")
        refute_includes(output, "-> Moving:")

        assert_includes(output, <<~OUTPUT)
          Removing RBI files of gems that have been removed:

            Nothing to do.
        OUTPUT

        assert_path_exists("#{outdir}/foo@0.0.1.rbi")
        assert_path_exists("#{outdir}/bar@0.3.0.rbi")
        assert_path_exists("#{outdir}/baz@0.0.2.rbi")
      end

      it "must move outdated RBIs" do
        ["foo@0.0.1.rbi", "bar@0.0.1.rbi", "baz@0.0.1.rbi"].each do |rbi|
          FileUtils.touch("#{outdir}/#{rbi}")
        end

        output = execute("sync")

        assert_includes(output, "-> Moving: #{outdir}/bar@0.0.1.rbi to #{outdir}/bar@0.3.0.rbi\n")
        assert_includes(output, "++ Adding: #{outdir}/bar@0.3.0.rbi\n")
        assert_includes(output, "-> Moving: #{outdir}/baz@0.0.1.rbi to #{outdir}/baz@0.0.2.rbi\n")
        assert_includes(output, "++ Adding: #{outdir}/baz@0.0.2.rbi\n")
        refute_includes(output, "-- Removing:")

        assert_includes(output, <<~OUTPUT)
          Removing RBI files of gems that have been removed:

            Nothing to do.
        OUTPUT

        assert_path_exists("#{outdir}/foo@0.0.1.rbi")
        assert_path_exists("#{outdir}/bar@0.3.0.rbi")
        assert_path_exists("#{outdir}/baz@0.0.2.rbi")

        refute_path_exists("#{outdir}/bar@0.0.1.rbi")
        refute_path_exists("#{outdir}/baz@0.0.1.rbi")
      end

      describe("verify") do
        before do
          execute("sync")
        end

        describe("with no changes") do
          it "does nothing and returns exit_status 0" do
            output = execute("sync", "--verify")

            assert_includes(output, <<~OUTPUT)
              Checking for out-of-date RBIs...

              Nothing to do, all RBIs are up-to-date.
            OUTPUT
            assert_includes($?.to_s, "exit 0") # rubocop:disable Style/SpecialGlobalVars
          end
        end

        describe("with excluded files") do
          it "advises of removed file(s) and returns exit_status 1" do
            output = execute("sync", "--verify", exclude: "foo bar")

            assert_includes(output, <<~OUTPUT)
              Checking for out-of-date RBIs...

              RBI files are out-of-date. In your development environment, please run:
                `bin/tapioca sync`
              Once it is complete, be sure to commit and push any changes

              Reason:
                File(s) removed:
                - #{outdir}/bar@0.3.0.rbi
                - #{outdir}/foo@0.0.1.rbi
            OUTPUT
            assert_includes($?.to_s, "exit 1") # rubocop:disable Style/SpecialGlobalVars

            # Does not actually modify anything
            assert_path_exists("#{outdir}/foo@0.0.1.rbi")
            assert_path_exists("#{outdir}/bar@0.3.0.rbi")
          end
        end

        describe("with added/removed/changed files") do
          before do
            FileUtils.rm("#{outdir}/foo@0.0.1.rbi")
            FileUtils.touch("#{outdir}/outdated@5.0.0.rbi")
            FileUtils.mv("#{outdir}/bar@0.3.0.rbi", "#{outdir}/bar@0.2.0.rbi")
          end

          it "advises of added/removed/changed file(s) and returns exit_status 1" do
            output = execute("sync", "--verify")

            assert_includes(output, <<~OUTPUT)
              Checking for out-of-date RBIs...

              RBI files are out-of-date. In your development environment, please run:
                `bin/tapioca sync`
              Once it is complete, be sure to commit and push any changes

              Reason:
                File(s) added:
                - #{outdir}/foo@0.0.1.rbi
                File(s) changed:
                - #{outdir}/bar@0.3.0.rbi
                File(s) removed:
                - #{outdir}/outdated@5.0.0.rbi
            OUTPUT
            assert_includes($?.to_s, "exit 1") # rubocop:disable Style/SpecialGlobalVars

            # Does not actually modify anything
            refute_path_exists("#{outdir}/foo@0.0.1.rbi")
            assert_path_exists("#{outdir}/outdated@5.0.0.rbi")
            assert_path_exists("#{outdir}/bar@0.2.0.rbi")
          end
        end
      end
    end
  end
end
