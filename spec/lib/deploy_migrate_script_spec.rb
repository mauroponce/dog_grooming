require "rails_helper"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "bin/deploy_migrate" do
  it "returns the migration command's failure status" do
    Dir.mktmpdir do |directory|
      bin_directory = File.join(directory, "bin")
      FileUtils.mkdir_p(bin_directory)
      FileUtils.cp(Rails.root.join("bin/deploy_migrate"), bin_directory)

      fake_rails = File.join(bin_directory, "rails")
      File.write(fake_rails, <<~BASH)
        #!/usr/bin/env bash
        if [ "$1" = "db:create" ]; then
          exit 0
        fi

        echo "simulated migration failure" >&2
        exit 42
      BASH
      FileUtils.chmod("u+x", fake_rails)

      _stdout, stderr, status = Open3.capture3(
        { "MIGRATION_LOCK_RETRIES" => "1" },
        File.join(bin_directory, "deploy_migrate"),
        chdir: directory
      )

      expect(status.exitstatus).to eq(42)
      expect(stderr).to include("simulated migration failure")
    end
  end
end
