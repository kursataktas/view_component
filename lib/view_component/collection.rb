# frozen_string_literal: true

require "action_view/renderer/collection_renderer" if Rails.version.to_f >= 6.1

module ViewComponent
  class Collection
    include Enumerable
    attr_reader :component

    delegate :size, to: :@collection

    attr_accessor :__vc_original_view_context

    def set_original_view_context(view_context)
      self.__vc_original_view_context = view_context
    end

    def render_in(view_context, &block)
      components.map do |component|
        component.set_original_view_context(__vc_original_view_context)
        component.render_in(view_context, &block)
      end.join.html_safe
    end

    def components
      return @components if defined? @components

      iterator = ActionView::PartialIteration.new(@collection.size)

      component.__vc_validate_collection_parameter!(validate_default: true)

      @components = @collection.map do |item|
        component.new(**component_options(item, iterator)).tap do |component|
          iterator.iterate!
        end
      end
    end

    def each(&block)
      components.each(&block)
    end

    # Rails expects us to define `format` on all renderables,
    # but we do not know the `format` of a ViewComponent until runtime.
    def format
      nil
    end

    private

    def initialize(component, object, **options)
      @component = component
      @collection = collection_variable(object || [])
      @options = options
    end

    def collection_variable(object)
      if object.respond_to?(:to_ary)
        object.to_ary
      else
        raise InvalidCollectionArgumentError
      end
    end

    def component_options(item, iterator)
      item_options = {component.__vc_collection_parameter => item}
      item_options[component.__vc_collection_counter_parameter] = iterator.index if component.__vc_counter_argument_present?
      item_options[component.__vc_collection_iteration_parameter] = iterator.dup if component.__vc_iteration_argument_present?

      @options.merge(item_options)
    end
  end
end
