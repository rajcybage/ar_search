require "active_record"

module ArSearch
  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  module ClassMethods
    def ar_search_scope(name, options)
      options_proc = case options
        when Proc
          options
        when Hash
          lambda { |query|
            options.reverse_merge(
              :match => query,
              :using => [:tsearch]
            )
          }
        else
          raise ArgumentError, "#{__method__} expects a Proc or Hash for the options"
      end

      scope_method = if self.respond_to?(:scope) && !protected_methods.include?('scope')
                       :scope
                     else
                       :named_scope
                     end

      send(scope_method, name, lambda { |*args|
        options = options_proc.call(*args)

        raise ArgumentError, "the search scope #{name} must have :against in its options" unless options[:against]

        matches_concatenated = Array.wrap(options[:against]).map do |match|
          "coalesce(#{quoted_table_name}.#{connection.quote_column_name(match)}, '')"
        end.join(" || ' ' || ")

        conditions = "to_tsvector('simple', #{matches_concatenated}) @@ plainto_tsquery('simple', :match)"

        {
          :conditions => [conditions, {:match => options[:match]}]
        }
      })
    end
  end
end
