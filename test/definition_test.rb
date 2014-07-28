require 'test_helper'

class DefinitionTest < MiniTest::Spec
  Definition = Representable::Definition

  # TODO: test that we DON'T clone options, that must happen in
  describe "#initialize" do
    it do
      opts = nil

      # new yields the defaultized options HASH.
      definition = Definition.new(:song, :extend => Module) do |options|
        options[:awesome] = true
        options[:parse_filter] << 1

        # default variables
        options[:as].must_equal "song"
        options[:extend].must_equal Module
      end

      #
      definition[:awesome].must_equal true
      definition[:parse_filter].instance_variable_get(:@value).must_equal Representable::Pipeline[1]
      definition[:render_filter].instance_variable_get(:@value).must_equal Representable::Pipeline[]
    end
  end

  describe "#[]" do
    let (:definition) { Definition.new(:song) }
    # default is nil.
    it { definition[:bla].must_equal nil }
  end

  # merge!
  describe "#merge!" do
    let (:definition) { Definition.new(:song) }

    it "runs macros" do
      definition[:setter].must_equal nil
      definition.merge!(:parse_strategy => :sync)
      definition[:setter].must_respond_to :evaluate
    end

    # with block
    it "xx" do
      definition = Definition.new(:song, :extend => Module).merge!({:something => true}) do |options|
        options[:awesome] = true
        options[:render_filter] << 1

        # default variables
        # options[:as].must_equal "song"
        # options[:extend].must_equal Module
      end

      definition[:awesome].must_equal true
      definition[:something].must_equal true
      definition[:render_filter].instance_variable_get(:@value).must_equal Representable::Pipeline[1]
      definition[:parse_filter].instance_variable_get(:@value).must_equal Representable::Pipeline[]
    end

    describe "with :parse_filter" do
      let (:definition) { Definition.new(:title, :parse_filter => 1) }

      # merges :parse_filter and :render_filter.
      it do
        merged = definition.merge!(:parse_filter => 2)[:parse_filter]

        merged.instance_variable_get(:@value).must_be_kind_of Representable::Pipeline
        merged.instance_variable_get(:@value).size.must_equal 2
      end

      # :parse_filter can also be array.
      it { definition.merge!(:parse_filter => [2, 3])[:parse_filter].instance_variable_get(:@value).size.must_equal 3 }
    end


    it { Definition.new(:title).merge!(:something => true)[:something].must_equal true }
  end


  describe "generic API" do
    before do
      @def = Representable::Definition.new(:songs)
    end

    it "responds to #representer_module" do
      assert_equal nil, Representable::Definition.new(:song).representer_module
      assert_equal Hash, Representable::Definition.new(:song, :extend => Hash).representer_module
    end

    describe "#typed?" do
      it "is false per default" do
        assert ! @def.typed?
      end

      it "is true when :class is present" do
        assert Representable::Definition.new(:songs, :class => Hash).typed?
      end

      it "is true when :extend is present, only" do
        assert Representable::Definition.new(:songs, :extend => Hash).typed?
      end

      it "is true when :instance is present, only" do
        assert Representable::Definition.new(:songs, :instance => Object.new).typed?
      end
    end


    describe "#representable?" do
      it { assert Definition.new(:song, :representable => true).representable? }
      it { Definition.new(:song, :representable => true, :extend => Object).representable?.must_equal true }
      it { refute Definition.new(:song, :representable => false, :extend => Object).representable? }
      it { assert Definition.new(:song, :extend => Object).representable? }
      it { refute Definition.new(:song).representable? }
    end


    it "responds to #getter and returns string" do
      assert_equal "songs", @def.getter
    end

    it "responds to #name" do
      assert_equal "songs", @def.name
    end

    it "responds to #setter" do
      assert_equal :"songs=", @def.setter
    end

    describe "#clone" do
      subject { Representable::Definition.new(:title, :volume => 9, :clonable => Uber::Options::Value.new(1)) }

      it { subject.clone.must_be_kind_of Representable::Definition }
      it { subject.clone[:clonable].evaluate(nil).must_equal 1 }

      it "clones @options" do
        @def.merge!(:volume => 9)

        cloned = @def.clone
        cloned.merge!(:volume => 8)

        assert_equal @def[:volume], 9
        assert_equal cloned[:volume], 8
      end
    end
  end

  describe "#has_default?" do
    it "returns false if no :default set" do
      assert_equal false, Representable::Definition.new(:song).has_default?
    end

    it "returns true if :default set" do
      assert_equal true, Representable::Definition.new(:song, :default => nil).has_default?
    end
  end


  describe "#skipable_empty_value?" do
    # default if skipable_empty_value?
    before do
      @def = Representable::Definition.new(:song, :render_nil => true)
    end

    it "returns false when not nil" do
      assert_equal false, @def.skipable_empty_value?("Disconnect, Disconnect")
    end

    it "returns false when nil and :render_nil => true" do
      assert_equal false, @def.skipable_empty_value?(nil)
    end

    it "returns true when nil and :render_nil => false" do
      assert_equal true, Representable::Definition.new(:song).skipable_empty_value?(nil)
    end

    it "returns false when not nil and :render_nil => false" do
      assert_equal false, Representable::Definition.new(:song).skipable_empty_value?("Fatal Flu")
    end
  end


  describe "#default_for" do
    before do
      @def = Representable::Definition.new(:song, :default => "Insider")
    end

    it "always returns value when value not nil" do
      assert_equal "Black And Blue", @def.default_for("Black And Blue")
    end

    it "returns false when value false" do
      assert_equal false, @def.default_for(false)
    end

    it "returns default when value nil" do
      assert_equal "Insider", @def.default_for(nil)
    end

    it "returns nil when value nil and :render_nil true" do
      @def = Representable::Definition.new(:song, :render_nil => true)
      assert_equal nil, @def.default_for(nil)
    end

    it "returns nil when value nil and :render_nil true even when :default is set" do
      @def = Representable::Definition.new(:song, :render_nil => true, :default => "The Quest")
      assert_equal nil, @def.default_for(nil)
    end

    it "returns nil if no :default" do
      @def = Representable::Definition.new(:song)
      assert_equal nil, @def.default_for(nil)
    end
  end


  describe "#writeable?" do

    it "returns true when :writeable is not given" do
      @def = Representable::Definition.new(:song)
      assert_equal true, @def.writeable?
    end

    it "returns true when :writeable => true" do
      @def = Representable::Definition.new(:song, :writeable => true)
      assert_equal true, @def.writeable?
    end

    it "returns false when :writeable => false" do
      @def = Representable::Definition.new(:song, :writeable => false)
      assert_equal false, @def.writeable?
    end

    it "returns nil when :writeable is nil" do
      @def = Representable::Definition.new(:song, :writeable => nil)
      assert_equal nil, @def.writeable?
    end

  end

  describe "#readable?" do

    it "returns true when :readable is not given" do
      @def = Representable::Definition.new(:song)
      assert_equal true, @def.readable?
    end

    it "returns true when :readable => true" do
      @def = Representable::Definition.new(:song, :readable => true)
      assert_equal true, @def.readable?
    end

    it "returns false when :readable => false" do
      @def = Representable::Definition.new(:song, :readable => false)
      assert_equal false, @def.readable?
    end

    it "returns nil when :readable is nil" do
      @def = Representable::Definition.new(:song, :readable => nil)
      assert_equal nil, @def.readable?
    end

  end

  describe "#binding" do
    it "returns true when :binding is set" do
      assert Representable::Definition.new(:songs, :binding => Object)[:binding]
    end

    it "returns false when :binding is not set" do
      assert !Representable::Definition.new(:songs)[:binding]
    end
  end

  describe "#create_binding" do
    it "executes the block (without special context)" do
      definition = Representable::Definition.new(:title, :binding => lambda { |*args| @binding = Representable::Binding.new(*args) })
      definition.create_binding(object=Object.new, nil, nil).must_equal @binding
      @binding.instance_variable_get(:@represented).must_equal object
    end
  end

  describe ":collection => true" do
    before do
      @def = Representable::Definition.new(:songs, :collection => true, :tag => :song)
    end

    it "responds to #array?" do
      assert @def.array?
    end
  end


  describe ":default => value" do
    it "responds to #default" do
      @def = Representable::Definition.new(:song)
      assert_equal nil, @def[:default]
    end

    it "accepts a default value" do
      @def = Representable::Definition.new(:song, :default => "Atheist Peace")
      assert_equal "Atheist Peace", @def[:default]
    end
  end

  describe ":hash => true" do
    before do
      @def = Representable::Definition.new(:songs, :hash => true)
    end

    it "responds to #hash?" do
      assert @def.hash?
      assert ! Representable::Definition.new(:songs).hash?
    end
  end

  describe ":binding => Object" do
    subject do
      Representable::Definition.new(:songs, :binding => Object)
    end

    it "responds to #binding" do
      assert_equal subject[:binding], Object
    end
  end

  describe "#[]=" do
    it "raises exception since it's deprecated" do
      assert_raises NoMethodError do
        Definition.new(:title)[:extend] = Module.new # use merge! after initialize.
      end
    end
  end
end
