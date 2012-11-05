module Locomotive
  module Extensions
    module SiteDataPresenter
      module ValidationAndSave

        include MinimalSave

        # Do a first pass where each new object is validated and saved minimally to
        # the database. Then validate and save all objects
        def insert
          self.clear_errors!
          self.ordered_models.each do |model|
            prepare_for_insert(model) do
              this_model_ok = minimal_save_model(model)
              this_model_ok &&= model_valid?(model, :always_use_indices => true)
              this_model_ok && save_model_without_validation(model)
            end
          end

          save_ok = self.no_errors?
          cleanup! unless save_ok
          save_ok
        end

        # Validate and save each object. Do not save any objects if any
        # validation fails
        def update
          return unless self.valid?
          self.save_all_without_validation
        end

        def errors
          @errors ||= {}.with_indifferent_access
        end

        protected

        # Yields object, model, *path
        def all_objects(always_use_indices = false, *models, &block)
          models = self.models if models.blank?
          self.class.ordered_normal_models.each do |model|
            next unless models.include?(model)
            self.send(:"#{model}").each_with_index do |obj, index|
              id = (obj.new_record? || always_use_indices) ? index : obj.id
              yield obj, model, id
            end
          end
          if models.include?('content_entries')
            self.content_entries.each do |content_type_slug, entries|
              entries.each_with_index do |obj, index|
                id = (obj.new_record? || always_use_indices) ? index : obj.id
                yield obj, 'content_entries', content_type_slug, id
              end
            end
          end
        end

        def depth_of_page(page)
          @page_depth ||= {}

          presenter = presenter_for(page)
          level_0_slug = ->(slug) { %w{index 404}.include?(slug) }

          @page_depth[page] ||= (if level_0_slug.call(page.slug)
              0
            elsif page.depth > 0
              page.depth
            elsif presenter.parent_fullpath
              if level_0_slug.call(presenter.parent_fullpath)
                1
              else
                presenter.parent_fullpath.split('/').size + 1
              end
            else
              1
            end)
        end

        def prepare_for_insert(model)
          entries = {}

          case model
          # If we're doing content_types, remove all entries as we insert
          when 'content_types'
            all_objects(false, model) do |obj|
              entries[obj] = [] + obj.entries
              obj.entries = []
            end
          # If we're doing pages, sort them by depth
          when 'pages'
            self.pages.sort_by! { |p| depth_of_page(p) }
            self.pages.each { |p| presenter_for(p).set_parent }
          end

          yield

          if model == 'content_types'
            all_objects(false, model) do |obj|
              obj.entries = entries[obj]
            end
          end
        end

        def save_model_without_validation(model)
          result = true
          all_objects(false, model) do |obj|
            presenter = presenter_for(obj)
            result = presenter.save(validate: false) && result
          end
          result
        end

        def save_all_without_validation
          result = true
          self.ordered_models.each do |model|
            result = self.save_model_without_validation(model) && result
          end
          result
        end

        def valid?
          self.clear_errors!
          self.models.each do |model|
            self.model_valid?(model)
          end
          self.no_errors?
        end

        def model_valid?(model, options = {})
          self.clear_errors!(model)
          all_objects(options[:always_use_indices], model) do |obj, model, *path|
            presenter = presenter_for(obj)
            unless presenter.valid?
              set_errors(presenter, model, *path)
            end
          end
          self.no_errors?(model)
        end

        def cleanup!
          all_objects do |obj|
            obj.destroy
          end
        end

        def set_errors(model_or_string, *path)
          is_string = model_or_string.kind_of?(String)

          # Build path
          current_container = self.errors
          current_element = nil
          path.each_with_index do |element, index|
            current_element = element
            unless index == path.length - 1
              current_container[element] ||= {}
              current_container = current_container[element]
            end
          end

          # Add error messages
          if is_string
            current_container[current_element] = [model_or_string]
          else
            current_container[current_element] = model_or_string.errors.messages
          end
        end

        def clear_errors!(model = nil)
          if model
            self.errors[model] = nil
          else
            self.errors.clear
          end
        end

        def no_errors?(model = nil)
          cleanup_errors!
          if model
            self.errors[model].blank?
          else
            self.errors.blank?
          end
        end

        def cleanup_errors!
          self.errors.each do |k, v|
            if v.blank?
              self.errors.delete(k)
            end
          end
        end

      end
    end
  end
end
