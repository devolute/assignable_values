module AssignableValues
  module ActiveRecord
    module Restriction
      class Base

        attr_reader :model, :property, :options, :values, :default, :secondary_default

        def initialize(model, property, options, &values)
          @model = model
          @property = property
          @options = options
          @values = values
          ensure_values_given
          setup_default
          define_assignable_values_method
          setup_validation
        end

        def validate_record(record)
          value = current_value(record)
          if  should?(record) && !should_not?(record)
            unless (allow_blank? && value.blank?) 
              begin
                assignable_values = assignable_values(record)
                [value].flatten.each do |v|
                  assignable_values.include?(v) or record.errors.add(property, not_included_error_message)
                end
              rescue DelegateUnavailable
                # if the delegate is unavailable, the validation is skipped
              end
            end
          end
        end
        
        def should?(record)
          @options[:if] ? call_condition(@options[:if],record) : true
        end
        
        def should_not?(record)
          @options[:unless] ? !call_condition(@options[:unless],record) : false
        end

        def call_condition(condition, record)
          if condition.kind_of?(Symbol)
            record.send(condition)
          elsif condition.kind_of?(Proc)
            if condition.arity == 1
              condition.call(record)
            elsif
              condition.call
            end
          end
        end        
        
        def not_included_error_message
          I18n.t('errors.messages.inclusion', :default => 'is not included in the list')
        end

        def assignable_value?(record, value)
          assignable_values(record).include?(value)
        end
        def assignable_values(record, decorate = false)
          assignable_values = []
          old_value = previously_saved_value(record)
          assignable_values << old_value if old_value.present?
          assignable_values |= raw_assignable_values(record)          
          if decorate
            assignable_values = decorate_values(assignable_values.flatten.uniq)
          end
          assignable_values
        end

        def set_default(record)
          if record.new_record? && record.send(property).nil?
            default_value = evaluate_default(record, default)
            begin
              if secondary_default? && !assignable_value?(record, default_value)
                  secondary_default_value = evaluate_default(record, secondary_default)
                  if assignable_value?(record, secondary_default_value)
                    default_value = secondary_default_value
                  end
              end
            rescue AssignableValues::DelegateUnavailable
              # skip secondary defaults if querying assignable values from a nil delegate
            end
            record.send("#{property}=", default_value)
          end          
          true
        end

        private

        def evaluate_default(record, value_or_proc)
          if value_or_proc.is_a?(Proc)
            record.instance_eval(&value_or_proc)
          else
            value_or_proc
          end
        end

        def parse_values(values)
          values.to_a
        end

        def current_value(record)
          record.send(property)
        end

        def previously_saved_value(record)
          nil
        end

        def decorate_values(values)
          values
        end

        def delegate?
          @options.has_key?(:through)
        end

        def default?
          @options.has_key?(:default)
        end

        def secondary_default?
          @options.has_key?(:secondary_default)
        end

        def allow_blank?
          @options[:allow_blank]
        end

        def delegate_definition
          options[:through]
        end

        def enhance_model(&block)
          @model.class_eval(&block)
        end

        def setup_default
          if default?
            @default = options[:default] # for attr_reader
            @secondary_default = options[:secondary_default] # for attr_reader
            ensure_after_initialize_callback_enabled
            restriction = self
            enhance_model do
              set_default_method = "set_default_#{restriction.property}"
              define_method set_default_method do
                restriction.set_default(self)
              end
              after_initialize set_default_method
            end
          elsif secondary_default?
            raise AssignableValues::NoDefault, "cannot use the :secondary_default option without a :default option"
          end
        end

        def ensure_after_initialize_callback_enabled
          if Rails.version < '3'
            enhance_model do
              # Old ActiveRecord version only call after_initialize callbacks only if this method is defined in a class.
              unless method_defined?(:after_initialize)
                define_method(:after_initialize) {}
              end
            end
          end
        end

        def setup_validation
          restriction = self
          enhance_model do
            validate_method = "validate_#{restriction.property}_assignable"
            define_method validate_method do
              restriction.validate_record(self)
            end
            validate validate_method
          end
        end

        def define_assignable_values_method
          restriction = self
          enhance_model do
            assignable_values_method = "assignable_#{restriction.property.to_s.pluralize}"
            define_method assignable_values_method do
              restriction.assignable_values(self, true)
            end
          end
        end

        def raw_assignable_values(record)
          if delegate?
            values = assignable_values_from_delegate(record)
          else
            values = record.instance_eval(&@values)
          end
          parse_values(values)
        end

        def delegate(record)
          case delegate_definition
          when Symbol then record.send(delegate_definition)
          when Proc then record.instance_eval(&delegate_definition)
          else raise "Illegal delegate definition: #{delegate_definition.inspect}"
          end
        end

        def assignable_values_from_delegate(record)
          delegate = delegate(record)
          delegate.present? or raise DelegateUnavailable, "Cannot query a nil delegate for assignable values"
          delegate_query_method = "assignable_#{model.name.underscore}_#{property.to_s.pluralize}"
          args = delegate.method(delegate_query_method).arity == 1 ? [record] : []
          delegate.send(delegate_query_method, *args)
        end

        def ensure_values_given
          @values or @options[:through] or raise NoValuesGiven, 'You must supply the list of assignable values by either a block or :through option'
        end

      end
    end
  end
end

