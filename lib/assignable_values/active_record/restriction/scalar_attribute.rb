module AssignableValues
  module ActiveRecord
    module Restriction
      class ScalarAttribute < Base

        def initialize(*args)
          super
          define_humanized_method
        end

        def humanize_string_value(value)
          if value.present?
            [value].flatten.map do |v|
              dictionary_key = "assignable_values.#{model.name.underscore}.#{property}.#{v}"           
              I18n.t(dictionary_key, :default => v.humanize)
            end.join(', ')
          end
        end

        def humanize_boolean_value(value)
          [value].flatten.map do |v|
            label = v ? "true" : "false"
            dictionary_key = "assignable_values.#{model.name.underscore}.#{property}.#{label}"
            I18n.t(dictionary_key, :default => label)
          end.join(', ')
         end

        def humanize_array_value(value, separator = ', ')
          value.map{|v| humanize_string_value(v)}.join(separator)
        end
        
        private

        def define_humanized_method

          restriction = self

          enhance_model do
            define_method "humanized_#{restriction.property}" do |*args|
              value = send(restriction.property)
              if value.kind_of?(String)
                restriction.humanize_string_value(value)
              elsif !!value == value
                restriction.humanize_boolean_value(value)
              elsif value.kind_of?(Array)
                restriction.humanize_array_value(value, *args)
              end
            end
          end
        end
        
              
        
        
        def humanize_type_for_value(value)
          return "string" if value.is_a?(String)
          return "boolean" if !!value == value
          return "array" if value.kind_of?(Array)
          false
        end
        
        def define_humanized_for_type(value)
          restriction = self
          case humanize_type_for_value(value)
            when "string"
            value.singleton_class.send(:define_method, :humanized) do
              restriction.humanize_string_value(value)
            end          
            when "boolean"
            value.singleton_class.send(:define_method, :humanized) do
              restriction.humanize_boolean_value(value)
            end
            when "array"
            value.each do |v|
              restriction.humanize_string_value(v)
            end
            end
          end
        end

        def decorate_values(values)
          restriction = self
          values.collect do |value|
            if value.kind_of?(String)
              value = value.dup
              define_humanized_for_type(value)
            elsif !!value == value
              define_humanized_for_type(value)
            end
            value
          end
        end      
        
        def previously_saved_value(record)
          record.send("#{property}_was") if record.respond_to?("#{property}_was")
        end

      end
    end
  end
end
