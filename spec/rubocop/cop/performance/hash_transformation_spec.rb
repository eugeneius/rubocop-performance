# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Performance::HashTransformation, :config do
  subject(:cop) { described_class.new(config) }

  context 'TargetRubyVersion <= 2.5', :ruby25 do
    %i[map collect].each do |method_name|
      it "does not register an offense for `#{method_name} { ... }.to_h`" do
        expect_no_offenses(<<~RUBY)
          hash.#{method_name} { |k, v| [v, k] }.to_h
        RUBY
      end

      it "does not register an offense for `Hash[#{method_name} { ... }]`" do
        expect_no_offenses(<<~RUBY)
          Hash[hash.#{method_name} { |k, v| [v, k] }]
        RUBY
      end
    end
  end

  context 'TargetRubyVersion >= 2.6', :ruby26 do
    %i[map collect].each do |method_name|
      caret_match = '^' * method_name.size

      it "registers an offense for `#{method_name} { ... }.to_h`" do
        expect_offense(<<~RUBY)
          hash.#{method_name} { |k, v| [v, k] }.to_h
               #{caret_match}^^^^^^^^^^^^^^^^^^^^^^^ Use `to_h { ... }` instead of `#{method_name} { ... }.to_h`.
        RUBY

        expect_correction(<<~RUBY)
          hash.to_h { |k, v| [v, k] }
        RUBY
      end

      it 'does not register an offense for ' \
         "`each_with_index.#{method_name} { ... }.to_h`" do
        expect_no_offenses(<<~RUBY)
          array.each_with_index.#{method_name} { |el, i| [i, el] }.to_h
        RUBY
      end

      it 'does not register an offense for ' \
         "`#{method_name} { ... }.to_h { ... }`" do
        expect_no_offenses(<<~RUBY)
          hash.#{method_name} { |k, v| [v, k] }.to_h { |k, v| [v, k] }
        RUBY
      end

      it "registers an offense for `Hash[#{method_name} { ... }]`" do
        expect_offense(<<~RUBY)
          Hash[hash.#{method_name} { |k, v| [v, k] }]
          ^^^^^^^^^^#{caret_match}^^^^^^^^^^^^^^^^^^^ Use `to_h { ... }` instead of `Hash[#{method_name} { ... }]`.
        RUBY

        expect_correction(<<~RUBY)
          hash.to_h { |k, v| [v, k] }
        RUBY
      end

      it 'does not register an offense for ' \
         "`Hash[each_with_index.#{method_name} { ... }]`" do
        expect_no_offenses(<<~RUBY)
          Hash[array.each_with_index.#{method_name} { |el, i| [i, el] }]
        RUBY
      end
    end

    it 'does not register an offense for `to_h { ... }`' do
      expect_no_offenses(<<~RUBY)
        hash.to_h { |k, v| [v, k] }
      RUBY
    end
  end
end
