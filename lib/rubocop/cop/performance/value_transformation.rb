# frozen_string_literal: true

module RuboCop
  module Cop
    module Performance
      # This cop identifies places where `map { ... }.to_h`, `Hash[map { ... }]`
      # or `to_h { ... }` can be replaced with `transform_values { ... }`,
      # saving an array allocation on each iteration.
      #
      # @example
      #   # bad
      #   hash.collect { |k, v| [k, v.to_s] }.to_h
      #   Hash[hash.map { |k, v| [k, v.to_s] }]
      #   hash.to_h { |k, v| [k, v.to_s] }
      #
      #   # good
      #   hash.transform_values { |v| v.to_s }
      class ValueTransformation < Cop
        include RangeHelp
        extend TargetRubyVersion

        minimum_target_ruby_version 2.4

        MSG = 'Use `transform_values { ... }` instead of `%<current>s`.'

        def_node_matcher :transform_values_candidate?, <<~PATTERN
          {
            [(send $(block
              $(send !(send _ :each_with_index) {:map :collect})
              (args (arg $_) (arg $_))
              (array (lvar _) $_)) :to_h) !block_literal?]
            (send (const nil? :Hash) :[] $(block
              $(send !(send _ :each_with_index) {:map :collect})
              (args (arg $_) (arg $_))
              (array (lvar _) $_)))
            $(block
              $(send !(send _ :each_with_index) :to_h)
              (args (arg $_) (arg $_))
              (array (lvar _) $_))
          }
        PATTERN

        def_node_search :lvar_reference?, <<~PATTERN
          (lvar %)
        PATTERN

        def on_send(node)
          transform_values_candidate?(node) do |_, call, key, value, expression|
            next if key_modified?(key, expression)
            next unless value_modified?(value, expression)
            next if lvar_reference?(expression, key)

            range = offense_range(node, call)
            message = message(node, call)
            add_offense(node, location: range, message: message)
          end
        end
        alias on_block on_send

        def autocorrect(node)
          block, call, _, _, expression = transform_values_candidate?(node)

          lambda do |corrector|
            corrector.remove(after_block(node, block))
            corrector.remove(after_expression(expression))
            corrector.remove(before_expression(expression))
            corrector.remove(key_parameter(block))
            corrector.replace(call.loc.selector, 'transform_values')
            corrector.remove(before_block(node, block))
          end
        end

        private

        def key_modified?(key, expression)
          key != expression.parent.children.first.children.first
        end

        def value_modified?(value, expression)
          !expression.lvar_type? || value != expression.children.last
        end

        def offense_range(node, call)
          if node.block_type?
            offense_range_for_block(node, call)
          elsif node.children.first.const_type?
            node.source_range
          else
            offense_range_for_map(node, call)
          end
        end

        def offense_range_for_block(node, call)
          range_between(call.loc.selector.begin_pos, node.loc.end.end_pos)
        end

        def offense_range_for_map(node, call)
          range_between(call.loc.selector.begin_pos, node.loc.selector.end_pos)
        end

        def message(node, call)
          current = if node.block_type?
                      'to_h { ... }'
                    elsif node.children.first.const_type?
                      "Hash[#{call.method_name} { ... }]"
                    else
                      "#{call.method_name} { ... }.to_h"
                    end

          format(MSG, current: current)
        end

        def after_block(node, block)
          block.source_range.end.join(node.source_range.end)
        end

        def after_expression(expression)
          expression.loc.expression.end.join(expression.parent.loc.end)
        end

        def before_expression(expression)
          expression.parent.loc.begin.join(expression.loc.expression.begin)
        end

        def key_parameter(block)
          key, value = block.arguments.children
          key.loc.expression.begin.join(value.loc.expression.begin)
        end

        def before_block(node, block)
          node.source_range.begin.join(block.source_range.begin)
        end
      end
    end
  end
end
