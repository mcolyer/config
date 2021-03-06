require 'helper'

describe Config::Patterns do

  let(:helper_class) {
    Class.new do
      include Config::Patterns

      attr_reader :klass

      def mock
        @mock ||= MiniTest::Mock.new
      end

      def add(klass)
        @klass = klass
        yield mock
      end
    end
  }

  subject { helper_class.new }

  let(:mock) { subject.mock }

  after do
    subject.klass.must_equal pattern
    mock.verify
  end

  describe "#file" do

    let(:pattern) { Config::Patterns::File }

    it "sets the path and adds the pattern" do
      mock.expect(:path=, nil, ["/tmp/file"])
      subject.file "/tmp/file", false
    end

    it "calls the block" do
      mock.expect(:path=, nil, ["/tmp/file"])
      mock.expect(:other=, nil, ["value"])
      subject.file "/tmp/file", false do |f|
        f.other = "value"
      end
    end

    it "allows simple template configuration" do
      mock.expect(:path=, nil, ["/tmp/file"])
      subject.file "/tmp/file", true do |f|
        f.must_be_instance_of Config::Patterns::FileTemplate
      end
    end
  end

  describe "#dir" do

    let(:pattern) { Config::Patterns::Directory }

    it "sets the path and adds the pattern" do
      mock.expect(:path=, nil, ["/tmp"])
      subject.dir "/tmp"
    end

    it "calls the block" do
      mock.expect(:path=, nil, ["/tmp"])
      mock.expect(:other=, nil, ["value"])
      subject.dir "/tmp" do |f|
        f.other = "value"
      end
    end
  end
end

describe Config::Patterns::FileTemplate do

  let(:pattern) { MiniTest::Mock.new }
  let(:context) { MiniTest::Mock.new }
  let(:source_file) { "/project/patterns/topic/pattern.rb" }

  subject { Config::Patterns::FileTemplate.new(pattern, context, source_file) }

  it "assigns template details" do
    pattern.expect(:template_path=, nil, ["/project/patterns/topic/templates/template.erb"])
    pattern.expect(:template_context=, nil, [context])
    subject.template = "template.erb"
  end

  it "assigns template details with a subdir" do
    pattern.expect(:template_path=, nil, ["/project/patterns/topic/templates/subdir/template.erb"])
    pattern.expect(:template_context=, nil, [context])
    subject.template = "subdir/template.erb"
  end

  it "delegates everything else" do
    pattern.expect(:public_send, "value", [:foo, "a", "b"])
    subject.foo("a", "b").must_equal "value"
  end
end
