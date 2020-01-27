# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Performance::ValueTransformation, :config do
  subject(:cop) { described_class.new(config) }

  context 'TargetRubyVersion <= 2.3', :ruby23 do
    %i[map collect].each do |method_name|
      it "does not register an offense for `#{method_name} { ... }.to_h`" do
        expect_no_offenses(<<~RUBY)
          hash.#{method_name} { |k, v| [k, v.to_s] }.to_h
        RUBY
      end

      it "does not register an offense for `Hash[#{method_name} { ... }]`" do
        expect_no_offenses(<<~RUBY)
          Hash[hash.#{method_name} { |k, v| [k, v.to_s] }]
        RUBY
      end
    end

    it 'does not register an offense for `to_h { ... }`' do
      expect_no_offenses(<<~RUBY)
        hash.to_h { |k, v| [k, v.to_s] }
      RUBY
    end
  end

  context 'TargetRubyVersion >= 2.4', :ruby24 do
    %i[map collect].each do |method_name|
      caret_match = '^' * method_name.size

      it "registers an offense for `#{method_name} { ... }.to_h`" do
        expect_offense(<<~RUBY)
          hash.#{method_name} { |k, v| [k, v.to_s] }.to_h
               #{caret_match}^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `transform_values { ... }` instead of `#{method_name} { ... }.to_h`.
        RUBY

        expect_correction(<<~RUBY)
          hash.transform_values { |v| v.to_s }
        RUBY
      end

      it "does not register an offense for `#{method_name} { ... }.to_h` " \
         'when the new value depends on the key' do
        expect_no_offenses(<<~RUBY)
          hash.#{method_name} { |k, v| [k, k] }.to_h
        RUBY
      end

      it "does not register an offense for `#{method_name} { ... }.to_h` " \
         'when neither key nor value are changed' do
        expect_no_offenses(<<~RUBY)
          hash.#{method_name} { |k, v| [k, v] }.to_h
        RUBY
      end

      it "does not register an offense for `#{method_name} { ... }.to_h` " \
         'when both key and value are changed' do
        expect_no_offenses(<<~RUBY)
          hash.#{method_name} { |k, v| [k.to_s, v.to_s] }.to_h
        RUBY
      end

      it 'does not register an offense for ' \
         "`each_with_index.#{method_name} { ... }.to_h`" do
        expect_no_offenses(<<~RUBY)
          array.each_with_index.#{method_name} { |el, i| [el, i.to_s] }.to_h
        RUBY
      end

      it 'does not register an offense for ' \
         "`#{method_name} { ... }.to_h { ... }`" do
        expect_no_offenses(<<~RUBY)
          hash.#{method_name} { |k, v| [k, v.to_s] }.to_h { |k, v| [v, k] }
        RUBY
      end

      it "registers an offense for `Hash[#{method_name} { ... }]`" do
        expect_offense(<<~RUBY)
          Hash[hash.#{method_name} { |k, v| [k, v.to_s] }]
          ^^^^^^^^^^#{caret_match}^^^^^^^^^^^^^^^^^^^^^^^^ Use `transform_values { ... }` instead of `Hash[#{method_name} { ... }]`.
        RUBY

        expect_correction(<<~RUBY)
          hash.transform_values { |v| v.to_s }
        RUBY
      end

      it "does not register an offense for `Hash[#{method_name} { ... }]` " \
         'when the new value depends on the key' do
        expect_no_offenses(<<~RUBY)
          Hash[hash.#{method_name} { |k, v| [k, k] }]
        RUBY
      end

      it "does not register an offense for `Hash[#{method_name} { ... }]` " \
         'when neither key nor value are changed' do
        expect_no_offenses(<<~RUBY)
          Hash[hash.#{method_name} { |k, v| [k, v] }]
        RUBY
      end

      it "does not register an offense for `Hash[#{method_name} { ... }]` " \
         'when both key and value are changed' do
        expect_no_offenses(<<~RUBY)
          Hash[hash.#{method_name} { |k, v| [k.to_s, v.to_s] }]
        RUBY
      end

      it 'does not register an offense for ' \
         "`Hash[each_with_index.#{method_name} { ... }]`" do
        expect_no_offenses(<<~RUBY)
          Hash[array.each_with_index.#{method_name} { |el, i| [el, i.to_s] }]
        RUBY
      end
    end

    it 'registers an offense for `to_h { ... }`' do
      expect_offense(<<~RUBY)
        hash.to_h { |k, v| [k, v.to_s] }
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `transform_values { ... }` instead of `to_h { ... }`.
      RUBY

      expect_correction(<<~RUBY)
        hash.transform_values { |v| v.to_s }
      RUBY
    end

    it 'does not register an offense for `to_h { ... }` when the new value ' \
       'depends on the key' do
      expect_no_offenses(<<~RUBY)
        hash.to_h { |k, v| [k, k] }
      RUBY
    end

    it 'does not register an offense for `to_h { ... }` when neither key nor ' \
       'value are changed' do
      expect_no_offenses(<<~RUBY)
        hash.to_h { |k, v| [k, v] }
      RUBY
    end

    it 'does not register an offense for `to_h { ... }` when both key and ' \
       'value are changed' do
      expect_no_offenses(<<~RUBY)
        hash.to_h { |k, v| [k.to_s, v.to_s] }
      RUBY
    end

    it 'does not register an offense for `each_with_index.to_h { ... }`' do
      expect_no_offenses(<<~RUBY)
        array.each_with_index.to_h { |el, i| [el, i.to_s] }
      RUBY
    end
  end
end
