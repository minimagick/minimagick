require "forwardable"

module MiniMagick
  module Utilities
    class ArrayMethods < Module

      ALL = Array.instance_methods(false) - Enumerable.instance_methods
      SHOULD_RETURN_BASE_CLASS = ALL & [
        :concat, :<<, :push, :unshift, :insert, :reverse, :reverse!, :rotate,
        :rotate!, :sort!, :sort_by!, :select!, :keep_if, :delete_if, :reject!,
        :replace, :clear, :fill, :slice, :slice!, :+, :*, :-, :&, :|, :uniq,
        :uniq!, :compact, :compact!, :shuffle!, :shuffle,
      ]
      SHOULD_YIELD_BASE_CLASS = ALL & [
        :permutation, :repeated_permutation,
        :combination, :repeated_combination,
      ]

      def initialize(delegate_to)
        super() do
          def_delegators delegate_to, *ALL

          return_base_class *SHOULD_RETURN_BASE_CLASS
          yield_base_class  *SHOULD_YIELD_BASE_CLASS
        end
      end

      include Forwardable

      def return_base_class(*names)
        names.each do |name|
          current_method = instance_method(name)
          define_method(name) do |*args, &block|
            result = current_method.bind(self).call(*args, &block)
            self.class.new(result)
          end
        end
      end

      def yield_base_class(*names)
        names.each do |name|
          current_method = instance_method(name)
          define_method(name) do |*args, &block|
            current_method.bind(self).call(*args) do |result|
              block.call self.class.new(result)
            end
          end
        end
      end

      def to_s
        "ArrayMethods"
      end

    end
  end
end
