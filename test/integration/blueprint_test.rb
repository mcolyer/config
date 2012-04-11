require 'helper'

module BlueprintTest

  class << self
    attr_accessor :value
  end

  # A pattern that sets a variable.
  class Test < Config::Pattern
    desc "The name"
    key  :name
    desc "The value"
    attr :value
    def create
      BlueprintTest.value << [name, value]
    end
    def destroy
      BlueprintTest.value << [:destroy, name]
    end
  end

  describe Config::Blueprint do

    before do
      BlueprintTest.value = []
    end

    subject { Config::Blueprint.from_string("test", code) }

    def log_execute(*args)
      stream = StringIO.new
      subject.log = Config::Log.new(stream)
      begin
        subject.execute(*args)
      rescue
        # ignore
      end
      stream.string
    end

    describe "in general" do

      let(:code) {
        <<-STR
          add BlueprintTest::Test do |t|
            t.name = "one"
            t.value = 1
          end
          add BlueprintTest::Test do |t|
            t.name = "two"
            t.value = 2
          end
        STR
      }

      it "has a name" do
        subject.to_s.must_equal "Blueprint test"
      end

      it "accumulates the patterns" do
        accumulation = subject.accumulate
        accumulation.size.must_equal 2
      end

      it "executes the patterns" do
        subject.validate
        BlueprintTest.value.must_equal []
        subject.execute
        BlueprintTest.value.must_equal [
          ["one", 1],
          ["two", 2]
        ]
      end

      it "logs what happened" do
        log_execute.must_equal <<-STR
Accumulate Blueprint test
Validate Blueprint test
Resolve Blueprint test
Execute Blueprint test
  Create [BlueprintTest::Test name:"one"]
  Create [BlueprintTest::Test name:"two"]
        STR
      end
    end

    describe "with invalid patterns" do

      let(:code) {
        <<-STR
          add BlueprintTest::Test do |t|
            t.name = "the test"
            # no value set
          end
        STR
      }

      it "detects validation errors" do
        subject.accumulate
        proc { subject.validate }.must_raise Config::Core::ValidationError
      end

      it "logs what happened" do
        log_execute.must_equal <<-STR
Accumulate Blueprint test
Validate Blueprint test
  ERROR [BlueprintTest::Test name:"the test"] missing value for :value (The value)
        STR
      end
    end

    describe "with conflicting patterns" do

      let(:code) {
        <<-STR
          add BlueprintTest::Test do |t|
            t.name = "the test"
            t.value = 1
          end
          add BlueprintTest::Test do |t|
            t.name = "the test"
            t.value = 2
          end
        STR
      }

      it "detects conflict errors" do
        proc { subject.validate }.must_raise Config::Core::ConflictError
      end

      it "logs what happened" do
        log_execute.must_equal <<-STR
Accumulate Blueprint test
Validate Blueprint test
Resolve Blueprint test
  CONFLICT [BlueprintTest::Test name:"the test"] {:name=>"the test", :value=>1} vs. [BlueprintTest::Test name:"the test"] {:name=>"the test", :value=>2}
        STR
      end
    end

    describe "with duplicate patterns" do

      let(:code) {
        <<-STR
          add BlueprintTest::Test do |t|
            t.name = "the test"
            t.value = "ok"
          end
          add BlueprintTest::Test do |t|
            t.name = "the test"
            t.value = "ok"
          end
        STR
      }

      it "only runs one pattern" do
        subject.validate
        BlueprintTest.value.must_equal []
        subject.execute
        BlueprintTest.value.must_equal [
          ["the test", "ok"]
        ]
      end

      it "logs what happened" do
        log_execute.must_equal <<-STR
Accumulate Blueprint test
Validate Blueprint test
Resolve Blueprint test
Execute Blueprint test
  Create [BlueprintTest::Test name:"the test"]
  Skip [BlueprintTest::Test name:"the test"]
        STR
      end
    end

    describe "with a previous accumulation" do

      let(:code1) {
        <<-STR
          add BlueprintTest::Test do |t|
            t.name = "pattern1"
            t.value = "ok"
          end
          add BlueprintTest::Test do |t|
            t.name = "pattern2"
            t.value = "ok"
          end
        STR
      }

      let(:code2) {
        <<-STR
          add BlueprintTest::Test do |t|
            t.name = "pattern2"
            t.value = "ok"
          end
        STR
      }

      let(:previous) { Config::Blueprint.from_string("test", code1) }
      subject        { Config::Blueprint.from_string("test", code2) }

      before do
        @accumulation = previous.accumulate
        previous.execute
      end

      it "destroys the removed pattern" do
        subject.execute(@accumulation)
        BlueprintTest.value.must_equal [
          ["pattern1", "ok"],
          ["pattern2", "ok"],
          [:destroy, "pattern1"],
          ["pattern2", "ok"]
        ]
      end

      it "logs what happened" do
        log_execute(@accumulation).must_equal <<-STR
Accumulate Blueprint test
Validate Blueprint test
Resolve Blueprint test
Execute Blueprint test
  Destroy [BlueprintTest::Test name:"pattern1"]
  Create [BlueprintTest::Test name:"pattern2"]
        STR
      end
    end
  end
end
