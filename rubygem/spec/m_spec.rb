require 'spec_helper'
require 'fake_mini_test'

describe Zeus::M::Runner do
  Runner = Zeus::M::Runner

  context "given a test with a question mark" do
    before do
      MiniTest::Unit::TestCase.stub!(:test_suites).and_return [fake_suite_with_special_characters]
      MiniTest::Unit.stub!(:runner).and_return fake_runner
    end

    it "escapes the question mark when using line number" do
      argv = ["path/to/file.rb:2"]

      fake_runner.should_receive(:run).with(["-n", "/(test_my_test_method\\?)/"])

      lambda { Runner.new(argv).run }.should exit_with_code(0)
    end

    it "escapes the question mark from explicit names" do
      argv = ["path/to/file.rb", "--name", fake_special_characters_test_method]

      fake_runner.should_receive(:run).with(["-n", "test_my_test_method\\?"])

      lambda { Runner.new(argv).run }.should exit_with_code(0)
    end
  end
end

describe Zeus::M::Runner do
  Runner = Zeus::M::Runner

  before do
    stub_mini_test_methods
  end

  context "no option is given" do
    it "runs the test without giving any option" do
      argv = ["path/to/file.rb"]

      fake_runner.should_receive(:run).with([])

      lambda { Runner.new(argv).run }.should exit_with_code(0)
    end
  end

  context "given a line number" do
    it "aborts if no test is found" do
      argv = ["path/to/file.rb:100"]

      STDERR.should_receive(:write).with(/No tests found on line 100/)
      fake_runner.should_not_receive :run

      lambda { Runner.new(argv).run }.should_not exit_with_code(0)
    end

    it "runs the test if the correct line number is given" do
      argv = ["path/to/file.rb:2"]

      fake_runner.should_receive(:run).with(["-n", "/(#{fake_test_method})/"])

      lambda { Runner.new(argv).run }.should exit_with_code(0)
    end
  end

  context "specifying test name" do
    it "runs the specified tests when using a pattern in --name option" do
      argv = ["path/to/file.rb", "--name", "/#{fake_test_method}/"]

      fake_runner.should_receive(:run).with(["-n", "/#{fake_test_method}/"])

      lambda { Runner.new(argv).run }.should exit_with_code(0)
    end

    it "runs the specified tests when using a pattern in -n option" do
      argv = ["path/to/file.rb", "-n", "/method/"]

      fake_runner.should_receive(:run).with(["-n", "/method/"])

      lambda { Runner.new(argv).run }.should exit_with_code(0)
    end

    it "aborts if no test matches the given pattern" do
      argv = ["path/to/file.rb", "-n", "/garbage/"]

      STDERR.should_receive(:write).with(%r{No test name matches \'/garbage/\'})
      fake_runner.should_not_receive :run

      lambda { Runner.new(argv).run }.should_not exit_with_code(0)
    end

    it "runs the specified tests when using a name (no pattern)" do
      argv = ["path/to/file.rb", "-n", "#{fake_test_method}"]

      fake_runner.should_receive(:run).with(["-n", fake_test_method])

      lambda { Runner.new(argv).run }.should exit_with_code(0)
    end

    it "aborts if no test matches the given test name" do
      argv = ["path/to/file.rb", "-n", "method"]

      STDERR.should_receive(:write).with(%r{No test name matches \'method\'})
      fake_runner.should_not_receive :run

      lambda { Runner.new(argv).run }.should_not exit_with_code(0)
    end
  end
end
