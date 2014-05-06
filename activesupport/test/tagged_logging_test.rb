require 'abstract_unit'
require 'active_support/core_ext/logger'
require 'active_support/tagged_logging'

class TaggedLoggingTest < ActiveSupport::TestCase
  class MyLogger < ::Logger
    attr_accessor :last_message
    attr_accessor :last_progname
    
    def flush(*)
      info "[FLUSHED]"
    end
    
    def add(severity, message = nil, progname = nil, &block)
      @last_message = message
      @last_progname = progname
      super(severity, message, progname, &block)
    end
  end

  setup do
    @output = StringIO.new
    @my_logger = MyLogger.new(@output)
    @logger = ActiveSupport::TaggedLogging.new(@my_logger)
  end

  test "tagged once" do
    @logger.tagged("BCX") { @logger.info "Funky time" }
    assert_equal "[BCX] Funky time\n", @output.string
  end
  
  test "tagged twice" do
    @logger.tagged("BCX") { @logger.tagged("Jason") { @logger.info "Funky time" } }
    assert_equal "[BCX] [Jason] Funky time\n", @output.string
  end

  test "tagged thrice at once" do
    @logger.tagged("BCX", "Jason", "New") { @logger.info "Funky time" }
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test "tagged are flattened" do
    @logger.tagged("BCX", %w(Jason New)) { @logger.info "Funky time" }
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test "push and pop tags directly" do
    assert_equal %w(A B C), @logger.push_tags('A', ['B', '  ', ['C']])
    @logger.info 'a'
    assert_equal %w(C), @logger.pop_tags
    @logger.info 'b'
    assert_equal %w(B), @logger.pop_tags(1)
    @logger.info 'c'
    assert_equal [], @logger.clear_tags!
    @logger.info 'd'
    assert_equal "[A] [B] [C] a\n[A] [B] b\n[A] c\nd\n", @output.string
  end

  test "does not strip message content" do
    @logger.info "  Hello"
    assert_equal "  Hello\n", @output.string
  end

  test "provides access to the logger instance" do
    @logger.tagged("BCX") { |logger| logger.info "Funky time" }
    assert_equal "[BCX] Funky time\n", @output.string
  end

  test "correctly answers responds_to_missing? for methods on logger instance" do
    assert @logger.respond_to?(:debug?)
  end

  test "tagged once with blank and nil" do
    @logger.tagged(nil, "", "New") { @logger.info "Funky time" }
    assert_equal "[New] Funky time\n", @output.string
  end

  test "keeps each tag in their own thread" do
    @logger.tagged("BCX") do
      Thread.new do
        @logger.tagged("OMG") { @logger.info "Cool story bro" }
      end.join
      @logger.info "Funky time"
    end
    assert_equal "[OMG] Cool story bro\n[BCX] Funky time\n", @output.string
  end

  test "cleans up the taggings on flush" do
    @logger.tagged("BCX") do
      Thread.new do
        @logger.tagged("OMG") do
          @logger.flush
          @logger.info "Cool story bro"
        end
      end.join
    end
    assert_equal "[FLUSHED]\nCool story bro\n", @output.string
  end

  test "mixed levels of tagging" do
    @logger.tagged("BCX") do
      @logger.tagged("Jason") { @logger.info "Funky time" }
      @logger.info "Junky time!"
    end

    assert_equal "[BCX] [Jason] Funky time\n[BCX] Junky time!\n", @output.string
  end

  test "silence" do
    assert_deprecated do
      assert_nothing_raised { @logger.silence {} }
    end
  end

  test "calls block" do
    @logger.tagged("BCX") do
      @logger.info { "Funky town" }
    end
    assert_equal "[BCX] Funky town\n", @output.string
  end

end
